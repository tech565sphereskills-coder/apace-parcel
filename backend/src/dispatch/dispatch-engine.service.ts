import {
  Injectable,
  ConflictException,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
  Logger,
} from '@nestjs/common';
import { OfferStatus, OrderStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { TrackingGateway } from '../tracking/tracking.gateway';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class DispatchEngineService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DispatchEngineService.name);
  private readonly timers = new Map<string, NodeJS.Timeout>();

  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
    private trackingGateway: TrackingGateway,
    private notificationsService: NotificationsService,
  ) {}

  async onModuleInit() {
    const activePending = await this.prisma.dispatchOffer.findMany({
      where: { status: OfferStatus.PENDING },
    });
    const now = Date.now();
    for (const offer of activePending) {
      const remainingMs = offer.expiresAt.getTime() - now;
      if (remainingMs <= 0) {
        this.handleOfferTimeout(offer.id).catch((err) =>
          this.logger.warn(`Boot cascade warning: ${(err as Error).message}`),
        );
      } else {
        const timer = setTimeout(() => {
          this.handleOfferTimeout(offer.id).catch((err) =>
            this.logger.warn(`Recovered offer timeout warning: ${(err as Error).message}`),
          );
        }, remainingMs);
        this.timers.set(offer.orderId, timer);
      }
    }
  }

  onModuleDestroy() {
    for (const timer of this.timers.values()) {
      clearTimeout(timer);
    }
    this.timers.clear();
  }

  private clearOrderTimer(orderId: string) {
    const existing = this.timers.get(orderId);
    if (existing) {
      clearTimeout(existing);
      this.timers.delete(orderId);
    }
  }

  private haversineKm(lat1?: number | null, lng1?: number | null, lat2?: number | null, lng2?: number | null): number {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      return 3.5;
    }
    const toRad = (d: number) => (d * Math.PI) / 180;
    const r = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    return r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  async startAuctionForOrder(orderId: string) {
    this.clearOrderTimer(orderId);
    await this.prisma.dispatchOffer.updateMany({
      where: { orderId, status: OfferStatus.PENDING },
      data: { status: OfferStatus.CANCELLED },
    });
    return this.dispatchNextRider(orderId, 1);
  }

  async dispatchNextRider(orderId: string, attemptNumber: number) {
    this.clearOrderTimer(orderId);
    if (attemptNumber > 6) {
      return { status: 'exhausted', orderId };
    }

    const order = await this.prisma.deliveryOrder.findUnique({ where: { id: orderId } });
    if (!order || order.status !== OrderStatus.SEARCHING || order.riderId !== null) {
      return { status: 'not_searching', orderId };
    }

    const priorOffers = await this.prisma.dispatchOffer.findMany({
      where: { orderId },
      select: { riderId: true, status: true },
    });
    const declinedIds = new Set(
      priorOffers.filter((o) => o.status === OfferStatus.DECLINED).map((o) => o.riderId),
    );
    const triedIds = new Set(priorOffers.map((o) => o.riderId));

    const onlineRiders = await this.prisma.riderProfile.findMany({
      where: {
        isOnline: true,
        userId: { not: order.senderId },
        user: {
          isDeleted: false,
          assignedOrders: {
            none: {
              status: {
                in: [OrderStatus.ASSIGNED, OrderStatus.PICKED_UP, OrderStatus.IN_TRANSIT],
              },
            },
          },
        },
      },
      include: {
        user: { select: { id: true, fullName: true } },
      },
    });

    let candidates = onlineRiders.filter((r) => !triedIds.has(r.userId));
    if (candidates.length === 0 && attemptNumber <= 3) {
      candidates = onlineRiders.filter((r) => !declinedIds.has(r.userId));
    }

    if (candidates.length === 0) {
      this.trackingGateway.server?.to(`order_${order.id}`).emit('dispatchSearching', {
        orderId: order.id,
        orderNumber: order.orderNumber,
        attemptNumber,
        message: 'All nearby riders busy — holding in open dispatch queue',
      });
      return { status: 'no_available_riders', orderId };
    }

    candidates.sort((a, b) => {
      const distA = this.haversineKm(order.pickupLat, order.pickupLng, a.currentLat, a.currentLng);
      const distB = this.haversineKm(order.pickupLat, order.pickupLng, b.currentLat, b.currentLng);
      return distA - a.rating * 0.5 - (distB - b.rating * 0.5);
    });

    const chosen = candidates[0];
    const surgeBonus = attemptNumber > 2 ? 250 : 0;
    const payoutAmount = Math.round(order.price * 0.8) + surgeBonus;
    const timeoutSeconds = 15;
    const expiresAt = new Date(Date.now() + timeoutSeconds * 1000);

    const offer = await this.prisma.dispatchOffer.create({
      data: {
        orderId: order.id,
        riderId: chosen.userId,
        attemptNumber,
        payoutAmount,
        status: OfferStatus.PENDING,
        expiresAt,
      },
    });

    const offerPayload = {
      offerId: offer.id,
      orderId: order.id,
      orderNumber: order.orderNumber,
      waybillNumber: order.waybillNumber,
      serviceType: order.serviceType,
      customerName: order.pickupContactName,
      customerPhone: order.pickupContactPhone,
      pickupAddress: order.pickupAddress,
      pickupLandmark: order.pickupLandmark,
      pickupLat: order.pickupLat,
      pickupLng: order.pickupLng,
      dropoffAddress: order.dropoffAddress,
      dropoffLandmark: order.dropoffLandmark,
      dropoffContactName: order.dropoffContactName,
      dropoffContactPhone: order.dropoffContactPhone,
      dropoffLat: order.dropoffLat,
      dropoffLng: order.dropoffLng,
      distanceKm: order.distanceKm,
      stopsCount: order.stopsCount,
      isEscrow: order.isEscrow,
      escrowAmount: order.escrowAmount,
      payoutAmount,
      attemptNumber,
      timeoutSeconds,
      expiresAt: expiresAt.toISOString(),
    };

    this.trackingGateway.server?.to(`rider_${chosen.userId}`).emit('dispatchOffer', offerPayload);
    this.trackingGateway.server?.to(`user_${chosen.userId}`).emit('dispatchOffer', offerPayload);

    this.notificationsService
      .sendPushToUser(
        chosen.userId,
        `New ₦${payoutAmount} Dispatch Offer`,
        `${order.pickupAddress} -> ${order.dropoffAddress} (Respond in ${timeoutSeconds}s)`,
        { type: 'DISPATCH_OFFER', offerId: offer.id, orderId: order.id },
      )
      .catch(() => {});

    this.trackingGateway.server?.to(`order_${order.id}`).emit('dispatchSearching', {
      orderId: order.id,
      orderNumber: order.orderNumber,
      attemptNumber,
      candidateRiderName: chosen.user.fullName,
      expiresAt: expiresAt.toISOString(),
    });

    const timer = setTimeout(() => {
      this.handleOfferTimeout(offer.id).catch((err) =>
        this.logger.warn(`Dispatch timeout handler warning: ${(err as Error).message}`),
      );
    }, timeoutSeconds * 1000);

    this.timers.set(order.id, timer);
    return { status: 'offered', offer };
  }

  async handleOfferTimeout(offerId: string) {
    const offer = await this.prisma.dispatchOffer.findUnique({ where: { id: offerId } });
    if (!offer || offer.status !== OfferStatus.PENDING) return;

    const expired = await this.prisma.dispatchOffer.updateMany({
      where: { id: offerId, status: OfferStatus.PENDING },
      data: { status: OfferStatus.EXPIRED, respondedAt: new Date() },
    });

    if (expired.count === 0) return;

    this.trackingGateway.server?.to(`rider_${offer.riderId}`).emit('dispatchOfferExpired', {
      offerId: offer.id,
      orderId: offer.orderId,
    });
    this.trackingGateway.server?.to(`user_${offer.riderId}`).emit('dispatchOfferExpired', {
      offerId: offer.id,
      orderId: offer.orderId,
    });

    await this.dispatchNextRider(offer.orderId, offer.attemptNumber + 1);
  }

  async acceptOffer(riderUserId: string, offerId: string) {
    const offer = await this.prisma.dispatchOffer.findUnique({
      where: { id: offerId },
      include: {
        order: true,
        rider: { select: { id: true, fullName: true, phone: true, riderProfile: true } },
      },
    });

    if (!offer || offer.riderId !== riderUserId) {
      throw new NotFoundException('Dispatch offer not found for your account');
    }

    this.clearOrderTimer(offer.orderId);

    const updatedOrder = await this.prisma.$transaction(async (tx) => {
      const offerUpdate = await tx.dispatchOffer.updateMany({
        where: {
          id: offer.id,
          riderId: riderUserId,
          status: OfferStatus.PENDING,
          expiresAt: { gt: new Date() },
        },
        data: {
          status: OfferStatus.ACCEPTED,
          respondedAt: new Date(),
        },
      });

      if (offerUpdate.count === 0) {
        throw new ConflictException('Dispatch offer expired or already answered');
      }

      const orderClaim = await tx.deliveryOrder.updateMany({
        where: {
          id: offer.orderId,
          status: OrderStatus.SEARCHING,
          riderId: null,
        },
        data: {
          riderId: riderUserId,
          status: OrderStatus.ASSIGNED,
        },
      });

      if (orderClaim.count === 0) {
        throw new ConflictException('Order has already been assigned to another rider');
      }

      await tx.dispatchOffer.updateMany({
        where: {
          orderId: offer.orderId,
          id: { not: offer.id },
          status: OfferStatus.PENDING,
        },
        data: { status: OfferStatus.CANCELLED },
      });

      return tx.deliveryOrder.findUnique({
        where: { id: offer.orderId },
        include: {
          stops: { orderBy: { sequence: 'asc' } },
          rider: { select: { id: true, fullName: true, phone: true, riderProfile: true } },
        },
      });
    });

    if (updatedOrder) {
      const event = {
        orderId: updatedOrder.id,
        orderNumber: updatedOrder.orderNumber,
        status: OrderStatus.ASSIGNED,
        rider: updatedOrder.rider,
      };
      this.trackingGateway.server?.to(`order_${updatedOrder.id}`).emit('orderStatusUpdated', event);
      this.trackingGateway.server
        ?.to(`order_${updatedOrder.orderNumber}`)
        .emit('orderStatusUpdated', event);
    }

    await this.auditService.log({
      userId: riderUserId,
      action: 'DISPATCH_OFFER_ACCEPTED',
      resource: 'DispatchOffer',
      resourceId: offer.id,
      metadata: { orderId: offer.orderId, attemptNumber: offer.attemptNumber },
    });

    return {
      message: `Dispatch ${offer.order.orderNumber} assigned to you`,
      order: updatedOrder,
      payoutAmount: offer.payoutAmount,
    };
  }

  async declineOffer(riderUserId: string, offerId: string) {
    const offer = await this.prisma.dispatchOffer.findUnique({ where: { id: offerId } });
    if (!offer || offer.riderId !== riderUserId) {
      throw new NotFoundException('Dispatch offer not found');
    }

    this.clearOrderTimer(offer.orderId);

    const declined = await this.prisma.dispatchOffer.updateMany({
      where: {
        id: offerId,
        riderId: riderUserId,
        status: OfferStatus.PENDING,
      },
      data: {
        status: OfferStatus.DECLINED,
        respondedAt: new Date(),
      },
    });

    if (declined.count === 0) {
      return { success: false, message: 'Offer already closed' };
    }

    const cascadeResult = await this.dispatchNextRider(offer.orderId, offer.attemptNumber + 1);
    return {
      success: true,
      message: 'Offer declined and reassigned to next nearby rider',
      cascade: cascadeResult,
    };
  }

  async getPendingOffersForRider(riderUserId: string) {
    const now = new Date();
    const offers = await this.prisma.dispatchOffer.findMany({
      where: {
        riderId: riderUserId,
        status: OfferStatus.PENDING,
        expiresAt: { gt: now },
        order: { status: OrderStatus.SEARCHING, riderId: null },
      },
      orderBy: { createdAt: 'desc' },
      include: {
        order: { include: { stops: { orderBy: { sequence: 'asc' } } } },
      },
    });

    return offers.map((offer) => ({
      offerId: offer.id,
      orderId: offer.orderId,
      orderNumber: offer.order.orderNumber,
      waybillNumber: offer.order.waybillNumber,
      serviceType: offer.order.serviceType,
      customerName: offer.order.pickupContactName,
      customerPhone: offer.order.pickupContactPhone,
      pickupAddress: offer.order.pickupAddress,
      pickupLandmark: offer.order.pickupLandmark,
      pickupLat: offer.order.pickupLat,
      pickupLng: offer.order.pickupLng,
      dropoffAddress: offer.order.dropoffAddress,
      dropoffLandmark: offer.order.dropoffLandmark,
      dropoffContactName: offer.order.dropoffContactName,
      dropoffContactPhone: offer.order.dropoffContactPhone,
      dropoffLat: offer.order.dropoffLat,
      dropoffLng: offer.order.dropoffLng,
      stops: offer.order.stops,
      distanceKm: offer.order.distanceKm,
      stopsCount: offer.order.stopsCount,
      isEscrow: offer.order.isEscrow,
      escrowAmount: offer.order.escrowAmount,
      payoutAmount: offer.payoutAmount,
      attemptNumber: offer.attemptNumber,
      remainingSeconds: Math.max(
        1,
        Math.ceil((offer.expiresAt.getTime() - now.getTime()) / 1000),
      ),
      expiresAt: offer.expiresAt.toISOString(),
    }));
  }
}
