import {
  Injectable,
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { OrderStatus, StopStatus, TransactionType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { TrackingGateway } from '../tracking/tracking.gateway';
import { DispatchEngineService } from '../dispatch/dispatch-engine.service';
import { NotificationsService } from '../notifications/notifications.service';
import {
  CompleteStopDto,
  ReportDelayDto,
  RiderOnboardDto,
  UpdateAvailabilityDto,
  UpdateOrderStatusDto,
} from './dto/rider.dto';

@Injectable()
export class RiderService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
    private trackingGateway: TrackingGateway,
    private dispatchEngine: DispatchEngineService,
    private notificationsService: NotificationsService,
  ) {}

  private async ensureRiderProfile(userId: string) {
    const existing = await this.prisma.riderProfile.findUnique({ where: { userId } });
    if (existing) return existing;
    return this.prisma.riderProfile.create({
      data: {
        userId,
        vehicleType: 'Bajaj Boxer 150cc',
        plateNumber: 'LAG-' + Math.floor(100 + Math.random() * 900) + '-AP',
        isOnline: true,
      },
    });
  }

  async getDashboard(userId: string) {
    const profile = await this.ensureRiderProfile(userId);
    const wallet = await this.prisma.wallet.findUnique({ where: { userId } });

    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);

    const todayPayouts = wallet
      ? await this.prisma.walletTransaction.aggregate({
          where: {
            walletId: wallet.id,
            category: TransactionType.RIDER_PAYOUT,
            createdAt: { gte: startOfDay },
          },
          _sum: { amount: true },
          _count: { id: true },
        })
      : { _sum: { amount: 0 }, _count: { id: 0 } };

    const activeOrder = await this.prisma.deliveryOrder.findFirst({
      where: {
        riderId: userId,
        status: { in: [OrderStatus.ASSIGNED, OrderStatus.PICKED_UP, OrderStatus.IN_TRANSIT] },
      },
      include: { stops: { orderBy: { sequence: 'asc' } } },
      orderBy: { updatedAt: 'desc' },
    });

    const pendingOffers = await this.dispatchEngine.getPendingOffersForRider(userId);

    return {
      profile,
      walletBalance: wallet?.balance || 0,
      todayEarnings: todayPayouts._sum.amount || 0,
      todayTrips: todayPayouts._count.id || 0,
      activeOrder,
      pendingOffers,
    };
  }

  async getPendingOffers(userId: string) {
    await this.ensureRiderProfile(userId);
    return this.dispatchEngine.getPendingOffersForRider(userId);
  }

  async acceptOffer(userId: string, offerId: string) {
    await this.ensureRiderProfile(userId);
    return this.dispatchEngine.acceptOffer(userId, offerId);
  }

  async declineOffer(userId: string, offerId: string) {
    await this.ensureRiderProfile(userId);
    return this.dispatchEngine.declineOffer(userId, offerId);
  }

  async updateAvailability(userId: string, dto: UpdateAvailabilityDto) {
    await this.ensureRiderProfile(userId);
    const updated = await this.prisma.riderProfile.update({
      where: { userId },
      data: {
        isOnline: dto.isOnline,
        currentLat: dto.latitude ?? undefined,
        currentLng: dto.longitude ?? undefined,
      },
    });
    return { success: true, profile: updated };
  }

  async getAvailableOrders() {
    return this.prisma.deliveryOrder.findMany({
      where: {
        status: OrderStatus.SEARCHING,
        riderId: null,
      },
      orderBy: { createdAt: 'desc' },
      take: 25,
      select: {
        id: true,
        orderNumber: true,
        waybillNumber: true,
        serviceType: true,
        pickupAddress: true,
        pickupLandmark: true,
        dropoffAddress: true,
        dropoffLandmark: true,
        distanceKm: true,
        price: true,
        stopsCount: true,
        scheduledTime: true,
        isEscrow: true,
        escrowAmount: true,
        createdAt: true,
      },
    });
  }

  async acceptOrder(userId: string, orderId: string) {
    await this.ensureRiderProfile(userId);

    const target = await this.prisma.deliveryOrder.findFirst({
      where: { OR: [{ id: orderId }, { orderNumber: orderId }] },
    });

    if (!target) {
      throw new NotFoundException('Delivery order not found');
    }

    if (target.senderId === userId) {
      throw new BadRequestException('Cannot accept your own customer dispatch order');
    }

    const claimed = await this.prisma.deliveryOrder.updateMany({
      where: {
        id: target.id,
        status: OrderStatus.SEARCHING,
        riderId: null,
      },
      data: {
        riderId: userId,
        status: OrderStatus.ASSIGNED,
      },
    });

    if (claimed.count === 0) {
      throw new ConflictException('Order has already been accepted by another rider');
    }

    const order = await this.prisma.deliveryOrder.findUnique({ where: { id: target.id } });

    this.trackingGateway.server?.to(`order_${target.id}`).emit('orderStatusUpdated', {
      orderId: target.id,
      orderNumber: target.orderNumber,
      status: OrderStatus.ASSIGNED,
      riderId: userId,
    });

    await this.auditService.log({
      userId,
      action: 'RIDER_ORDER_ACCEPTED',
      resource: 'DeliveryOrder',
      resourceId: target.id,
    });

    return {
      message: `Dispatch ${target.orderNumber} assigned to you`,
      order,
    };
  }

  async updateOrderStatus(userId: string, orderId: string, dto: UpdateOrderStatusDto) {
    const order = await this.prisma.deliveryOrder.findFirst({
      where: { OR: [{ id: orderId }, { orderNumber: orderId }] },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    if (order.riderId !== userId) {
      throw new ForbiddenException('You are not the assigned rider for this order');
    }

    const allowedTransitions: Record<OrderStatus, OrderStatus[]> = {
      [OrderStatus.SEARCHING]: [],
      [OrderStatus.ASSIGNED]: [OrderStatus.PICKED_UP, OrderStatus.IN_TRANSIT],
      [OrderStatus.PICKED_UP]: [OrderStatus.IN_TRANSIT, OrderStatus.DELIVERED],
      [OrderStatus.IN_TRANSIT]: [OrderStatus.DELIVERED],
      [OrderStatus.DELIVERED]: [],
      [OrderStatus.CANCELLED]: [],
    };

    if (!allowedTransitions[order.status].includes(dto.status)) {
      throw new BadRequestException(
        `Invalid status transition from ${order.status} to ${dto.status}`,
      );
    }

    if (dto.status === OrderStatus.DELIVERED) {
      if (!dto.handoverOtp || dto.handoverOtp !== order.handoverOtp) {
        throw new UnauthorizedException('Valid 4-digit recipient handover OTP is required');
      }
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const transitioned = await tx.deliveryOrder.updateMany({
        where: { id: order.id, status: order.status },
        data: {
          status: dto.status,
          hasProofOfDelivery:
            dto.status === OrderStatus.DELIVERED || Boolean(dto.recipientSignature || dto.proofPhotoUrl)
              ? true
              : order.hasProofOfDelivery,
          recipientSignature: dto.recipientSignature || order.recipientSignature,
          proofPhotoUrl: dto.proofPhotoUrl || order.proofPhotoUrl,
          deliveredAt: dto.status === OrderStatus.DELIVERED ? new Date() : order.deliveredAt,
        },
      });

      if (transitioned.count === 0) {
        throw new ConflictException('Order status changed concurrently');
      }

      if (dto.status === OrderStatus.DELIVERED) {
        const netPayout = Math.round(order.price * 0.8);
        const riderWallet = await tx.wallet.findUnique({ where: { userId } });
        if (riderWallet) {
          await tx.wallet.update({
            where: { id: riderWallet.id },
            data: { balance: { increment: netPayout } },
          });
          await tx.walletTransaction.create({
            data: {
              walletId: riderWallet.id,
              amount: netPayout,
              isCredit: true,
              title: `Trip Payout: ${order.orderNumber}`,
              subtitle: '80% dispatch fare earned',
              reference: `RIDER_PAY_${order.orderNumber}_${Date.now()}`,
              category: TransactionType.RIDER_PAYOUT,
            },
          });
        }
        await tx.riderProfile.updateMany({
          where: { userId },
          data: { totalTrips: { increment: 1 } },
        });
      }

      return tx.deliveryOrder.findUnique({ where: { id: order.id } });
    });

    this.trackingGateway.server?.to(`order_${order.id}`).emit('orderStatusUpdated', {
      orderId: order.id,
      orderNumber: order.orderNumber,
      status: dto.status,
      timestamp: new Date().toISOString(),
    });

    await this.auditService.log({
      userId,
      action: `ORDER_STATUS_${dto.status}`,
      resource: 'DeliveryOrder',
      resourceId: order.id,
    });

    return {
      message: `Order updated to ${dto.status}`,
      order: updated,
    };
  }

  async onboardRider(userId: string, dto: RiderOnboardDto) {
    await this.ensureRiderProfile(userId);
    const isProd = process.env.NODE_ENV === 'production';
    const nextApproval = isProd ? 'UNDER_REVIEW' : 'APPROVED';

    const [profile] = await this.prisma.$transaction([
      this.prisma.riderProfile.update({
        where: { userId },
        data: {
          vehicleType: dto.vehicleType,
          vehicleModel: dto.vehicleModel || dto.vehicleType,
          plateNumber: dto.plateNumber.toUpperCase().trim(),
          licenseNumber: dto.licenseNumber.toUpperCase().trim(),
          licensePhotoUrl: dto.licensePhotoUrl || undefined,
          guarantorName: dto.guarantorName.trim(),
          guarantorPhone: dto.guarantorPhone.trim(),
          approvalStatus: nextApproval,
          isVerified: nextApproval === 'APPROVED',
        },
      }),
      this.prisma.user.update({
        where: { id: userId },
        data: { role: 'RIDER' },
      }),
    ]);

    await this.auditService.log({
      userId,
      action: 'RIDER_COMPLIANCE_SUBMITTED',
      resource: 'RiderProfile',
      resourceId: userId,
      metadata: {
        plateNumber: profile.plateNumber,
        licenseNumber: profile.licenseNumber,
        approvalStatus: profile.approvalStatus,
      },
    });

    return {
      success: true,
      message:
        nextApproval === 'APPROVED'
          ? 'Rider compliance documents verified and fleet portal activated!'
          : 'Documents submitted for fleet safety inspection.',
      profile,
    };
  }

  async completeOrderStop(userId: string, stopId: string, dto: CompleteStopDto) {
    const stop = await this.prisma.orderStop.findUnique({
      where: { id: stopId },
      include: { order: true },
    });

    if (!stop) {
      throw new NotFoundException('Order stop sub-waybill not found');
    }
    if (stop.order.riderId !== userId) {
      throw new ForbiddenException('You are not the assigned rider for this stop');
    }
    if (stop.status === StopStatus.DELIVERED) {
      return { message: 'Stop already delivered', stop, order: stop.order };
    }

    if (
      dto.handoverOtp !== stop.handoverOtp &&
      dto.handoverOtp !== stop.order.handoverOtp
    ) {
      throw new UnauthorizedException('Invalid 4-digit stop handover OTP');
    }

    const result = await this.prisma.$transaction(async (tx) => {
      const updatedStop = await tx.orderStop.update({
        where: { id: stop.id },
        data: {
          status: StopStatus.DELIVERED,
          proofPhotoUrl: dto.proofPhotoUrl || stop.proofPhotoUrl,
          deliveredAt: new Date(),
        },
      });

      const remaining = await tx.orderStop.count({
        where: { orderId: stop.orderId, status: { not: StopStatus.DELIVERED } },
      });

      let updatedOrder = stop.order;
      if (remaining === 0) {
        const transitioned = await tx.deliveryOrder.updateMany({
          where: { id: stop.orderId, status: { not: OrderStatus.DELIVERED } },
          data: {
            status: OrderStatus.DELIVERED,
            hasProofOfDelivery: true,
            deliveredAt: new Date(),
          },
        });
        if (transitioned.count > 0) {
          const netPayout = Math.round(stop.order.price * 0.8);
          const riderWallet = await tx.wallet.findUnique({ where: { userId } });
          if (riderWallet) {
            await tx.wallet.update({
              where: { id: riderWallet.id },
              data: { balance: { increment: netPayout } },
            });
            await tx.walletTransaction.create({
              data: {
                walletId: riderWallet.id,
                amount: netPayout,
                isCredit: true,
                title: `Multi-Stop Payout: ${stop.order.orderNumber}`,
                subtitle: '80% dispatch corridor fare earned',
                reference: `RIDER_CORR_${stop.order.orderNumber}_${Date.now()}`,
                category: TransactionType.RIDER_PAYOUT,
              },
            });
          }
          await tx.riderProfile.updateMany({
            where: { userId },
            data: { totalTrips: { increment: 1 } },
          });
        }
        updatedOrder = (await tx.deliveryOrder.findUnique({
          where: { id: stop.orderId },
          include: { stops: { orderBy: { sequence: 'asc' } } },
        }))!;
      } else {
        updatedOrder = await tx.deliveryOrder.update({
          where: { id: stop.orderId },
          data: { currentStopIndex: { increment: 1 } },
          include: { stops: { orderBy: { sequence: 'asc' } } },
        });
      }

      return { updatedStop, updatedOrder, remaining };
    });

    this.trackingGateway.server?.to(`order_${stop.orderId}`).emit('orderStopCompleted', {
      orderId: stop.orderId,
      stopId: stop.id,
      sequence: stop.sequence,
      remainingStops: result.remaining,
    });

    if (result.remaining === 0) {
      this.trackingGateway.server?.to(`order_${stop.orderId}`).emit('orderStatusUpdated', {
        orderId: stop.orderId,
        orderNumber: stop.order.orderNumber,
        status: OrderStatus.DELIVERED,
        timestamp: new Date().toISOString(),
      });
    }

    return {
      message:
        result.remaining === 0
          ? 'Final stop delivered! Order completed and rider payout credited.'
          : `Sub-waybill ${stop.subWaybillCode} delivered. ${result.remaining} stop(s) remaining.`,
      stop: result.updatedStop,
      order: result.updatedOrder,
    };
  }

  async reportDelayFlag(userId: string, orderId: string, dto: ReportDelayDto) {
    const order = await this.prisma.deliveryOrder.findFirst({
      where: { OR: [{ id: orderId }, { orderNumber: orderId }] },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }
    if (order.riderId !== userId) {
      throw new ForbiddenException('You are not the assigned rider for this order');
    }

    const labelMap: Record<string, string> = {
      ESTATE_GATE_HOLD: 'Estate Security Gate Hold — Rider awaiting resident entry clearance',
      TRAFFIC_CONGESTION: 'Heavy Lagos / Highway Traffic — Rider rerouting via Google Maps',
      WEATHER_HOLD: 'Heavy Rain Hold — Parcel kept weather-sealed until safe movement',
    };
    const message = dto.note?.trim() || labelMap[dto.flagType] || 'Route delay reported by rider';

    const eventPayload = {
      orderId: order.id,
      orderNumber: order.orderNumber,
      flagType: dto.flagType,
      message,
      timestamp: new Date().toISOString(),
    };

    this.trackingGateway.server?.to(`order_${order.id}`).emit('orderDelayReported', eventPayload);
    this.trackingGateway.server
      ?.to(`order_${order.orderNumber}`)
      .emit('orderDelayReported', eventPayload);

    await this.notificationsService.sendPushToUser(
      order.senderId,
      `Route Update: ${order.orderNumber}`,
      message,
      { orderId: order.id, flagType: dto.flagType },
    );

    await this.auditService.log({
      userId,
      action: `RIDER_DELAY_${dto.flagType}`,
      resource: 'DeliveryOrder',
      resourceId: order.id,
      metadata: { message },
    });

    return {
      success: true,
      event: eventPayload,
    };
  }
}

