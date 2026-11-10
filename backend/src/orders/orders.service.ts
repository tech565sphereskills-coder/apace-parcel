import {
  Injectable,
  BadRequestException,
  NotFoundException,
  UnauthorizedException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { DispatchEngineService } from '../dispatch/dispatch-engine.service';
import { CreateOrderDto, CreateOrderStopDto, OptimizeCorridorDto } from './dto/create-order.dto';
import { EstimateFareDto } from './dto/estimate-fare.dto';
import { TipRiderDto } from './dto/tip-rider.dto';
import { OpenDisputeDto, SendChatDto, SubmitPodDto } from './dto/order-actions.dto';
import { OrderStatus, Role, ServiceType, TransactionType } from '@prisma/client';
import * as bcrypt from 'bcrypt';

@Injectable()
export class OrdersService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
    private dispatchEngine: DispatchEngineService,
  ) {}

  private inferNigerianCoords(
    address: string,
    explicitLat?: number,
    explicitLng?: number,
  ): { lat: number; lng: number } {
    if (explicitLat != null && explicitLng != null) {
      return { lat: explicitLat, lng: explicitLng };
    }
    const lower = (address || '').toLowerCase();
    const hubs: Array<[RegExp, number, number]> = [
      [/lekki|admiralty|chevron|ikate/, 6.4474, 3.4723],
      [/ajah|sangotedo|abraham/, 6.4698, 3.5852],
      [/victoria\s+island|\bvi\b|adeola|akin\s+adesola/, 6.4281, 3.4219],
      [/ikoyi|bourdillon|banana\s+island/, 6.4549, 3.4346],
      [/yaba|herbert\s+macaulay|sabo|akoka/, 6.5095, 3.3711],
      [/surulere|bode\s+thomas|adeniran/, 6.5059, 3.3509],
      [/ikeja|allen|alade|obafemi\s+awolowo|computer\s+village/, 6.6018, 3.3515],
      [/gbagada|maryland|anthony/, 6.5569, 3.3855],
      [/ogba|agege/, 6.6311, 3.3389],
      [/festac|amuwo/, 6.4664, 3.2835],
      [/wuse|aminu\s+kano/, 9.0765, 7.476],
      [/maitama/, 9.0882, 7.4934],
      [/garki/, 9.0333, 7.4833],
      [/asokoro/, 9.048, 7.524],
    ];
    for (const [pattern, lat, lng] of hubs) {
      if (pattern.test(lower)) {
        return { lat, lng };
      }
    }
    return { lat: 6.5244, lng: 3.3792 };
  }

  private sortCorridorStops(
    pickupAddress: string,
    pickupLat?: number,
    pickupLng?: number,
    stops: CreateOrderStopDto[] = [],
  ) {
    const start = this.inferNigerianCoords(pickupAddress, pickupLat, pickupLng);
    const enriched = stops.map((s, index) => {
      const coords = this.inferNigerianCoords(s.address, s.lat, s.lng);
      return {
        ...s,
        originalIndex: index,
        lat: coords.lat,
        lng: coords.lng,
      };
    });

    let rawKm = 0;
    let prevRaw = start;
    for (const stop of enriched) {
      rawKm += this.calculateHaversineKm(prevRaw.lat, prevRaw.lng, stop.lat, stop.lng) ?? 3.5;
      prevRaw = { lat: stop.lat, lng: stop.lng };
    }

    const remaining = [...enriched];
    const optimized: Array<(typeof enriched)[number] & { legKm: number }> = [];
    let current = start;
    let optimizedKm = 0;

    while (remaining.length > 0) {
      let bestIdx = 0;
      let bestDist = Infinity;
      for (let i = 0; i < remaining.length; i++) {
        const d =
          this.calculateHaversineKm(current.lat, current.lng, remaining[i].lat, remaining[i].lng) ??
          3.5;
        if (d < bestDist) {
          bestDist = d;
          bestIdx = i;
        }
      }
      const [chosen] = remaining.splice(bestIdx, 1);
      const roundedLeg = Math.round(bestDist * 10) / 10;
      optimizedKm += roundedLeg;
      optimized.push({ ...chosen, legKm: roundedLeg });
      current = { lat: chosen.lat, lng: chosen.lng };
    }

    const savedKm = Math.max(0, Math.round((rawKm - optimizedKm) * 10) / 10);
    const batchDiscountPercent = optimized.length >= 2 ? 15 : 0;
    const estimatedSavingsNgn = Math.round(savedKm * 180 + optimized.length * 250);

    return {
      pickup: start,
      optimizedStops: optimized.map((s, idx) => ({
        sequence: idx + 1,
        address: s.address,
        landmark: s.landmark || '',
        contactName: s.contactName,
        contactPhone: s.contactPhone,
        lat: s.lat,
        lng: s.lng,
        legKm: s.legKm,
      })),
      rawDistanceKm: Math.round(rawKm * 10) / 10,
      optimizedDistanceKm: Math.round(optimizedKm * 10) / 10,
      distanceSavedKm: savedKm,
      batchDiscountPercent,
      estimatedSavingsNgn,
    };
  }

  async optimizeCorridor(dto: OptimizeCorridorDto) {
    return this.sortCorridorStops(dto.pickupAddress, dto.pickupLat, dto.pickupLng, dto.stops);
  }

  private calculateHaversineKm(
    lat1?: number,
    lng1?: number,
    lat2?: number,
    lng2?: number,
  ): number | null {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      return null;
    }
    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const r = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(toRad(lat1)) *
        Math.cos(toRad(lat2)) *
        Math.sin(dLng / 2) *
        Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Math.max(1.5, Math.round(r * c * 10) / 10);
  }

  private calculateServiceFare(
    type: ServiceType,
    distanceKm: number,
    stopsCount = 1,
    includeInsurance = false,
  ) {
    let baseFare = 2450;
    switch (type) {
      case ServiceType.CAR:
        baseFare = Math.max(4500, Math.round(distanceKm * 280 + 1500));
        break;
      case ServiceType.VAN:
        baseFare = Math.max(12500, Math.round(distanceKm * 650 + 5000));
        break;
      case ServiceType.INTERSTATE:
        baseFare = Math.max(7500, Math.round(distanceKm * 400 + 4000));
        break;
      case ServiceType.BIKE:
      default:
        baseFare = Math.max(2200, Math.round(distanceKm * 150 + 1000));
        break;
    }
    const extraStops = Math.max(0, stopsCount - 1);
    const stopsFee = Math.round(extraStops * (baseFare * 0.55));
    const insuranceFee = includeInsurance ? 350 : 0;
    const totalPrice = baseFare + stopsFee + insuranceFee;
    return { baseFare, stopsFee, insuranceFee, totalPrice };
  }

  private assertOrderAccess(order: any, userId: string, role: Role) {
    if (role === Role.ADMIN) return;
    if (order.senderId !== userId && order.riderId !== userId) {
      throw new ForbiddenException('You do not have permission to access this delivery order');
    }
  }

  async estimateFare(dto: EstimateFareDto) {
    const computedKm = this.calculateHaversineKm(
      dto.pickupLat,
      dto.pickupLng,
      dto.dropoffLat,
      dto.dropoffLng,
    );
    const distance = computedKm ?? dto.distanceKm ?? 14.5;
    const stopsCount = dto.stopsCount ?? 1;
    const includeInsurance = dto.includeInsurance ?? false;

    return {
      distanceKm: distance,
      pickup: dto.pickupLocation,
      dropoff: dto.dropoffLocation,
      stopsCount,
      estimates: [
        {
          type: ServiceType.BIKE,
          title: 'Instant Bike Dispatch',
          subtitle: 'Beats Lagos & Abuja traffic',
          etaMinutes: Math.round(distance * 2.2 + 8),
          ...this.calculateServiceFare(ServiceType.BIKE, distance, stopsCount, includeInsurance),
          price: this.calculateServiceFare(ServiceType.BIKE, distance, stopsCount, includeInsurance).totalPrice,
        },
        {
          type: ServiceType.CAR,
          title: 'Express Car Delivery',
          subtitle: 'Delicate items, cakes, and gifts',
          etaMinutes: Math.round(distance * 3.0 + 15),
          ...this.calculateServiceFare(ServiceType.CAR, distance, stopsCount, includeInsurance),
          price: this.calculateServiceFare(ServiceType.CAR, distance, stopsCount, includeInsurance).totalPrice,
        },
        {
          type: ServiceType.VAN,
          title: 'Mini-Van / Cargo Bus',
          subtitle: 'Bulky goods, furniture, cartons',
          etaMinutes: Math.round(distance * 3.5 + 25),
          ...this.calculateServiceFare(ServiceType.VAN, distance, stopsCount, includeInsurance),
          price: this.calculateServiceFare(ServiceType.VAN, distance, stopsCount, includeInsurance).totalPrice,
        },
        {
          type: ServiceType.INTERSTATE,
          title: 'Interstate Cargo Waybill',
          subtitle: 'Lagos to Abuja, PH, Kano & nationwide',
          etaMinutes: 1440,
          ...this.calculateServiceFare(ServiceType.INTERSTATE, distance, stopsCount, includeInsurance),
          price: this.calculateServiceFare(ServiceType.INTERSTATE, distance, stopsCount, includeInsurance).totalPrice,
        },
      ],
    };
  }

  async createOrder(userId: string, dto: CreateOrderDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { wallet: true },
    });

    if (!user || user.isDeleted) {
      throw new NotFoundException('User not found');
    }

    const paymentMethod = dto.paymentMethod || 'WALLET';
    if (paymentMethod === 'WALLET' && user.transactionPinHash) {
      if (!dto.transactionPin) {
        throw new BadRequestException('4-digit transaction PIN is required for wallet dispatch payments');
      }
      const isPinMatch = await bcrypt.compare(dto.transactionPin, user.transactionPinHash);
      if (!isPinMatch) {
        throw new UnauthorizedException('Incorrect transaction PIN. Order creation unauthorized.');
      }
    }

    const resolvedPickup = this.inferNigerianCoords(
      dto.pickupAddress,
      dto.pickupLat,
      dto.pickupLng,
    );
    const resolvedDropoff = this.inferNigerianCoords(
      dto.dropoffAddress,
      dto.dropoffLat,
      dto.dropoffLng,
    );

    const hasExplicitStops = Array.isArray(dto.stops) && dto.stops.length > 0;
    const corridorPlan = hasExplicitStops
      ? this.sortCorridorStops(
          dto.pickupAddress,
          resolvedPickup.lat,
          resolvedPickup.lng,
          dto.stops,
        )
      : null;

    const computedKm = corridorPlan
      ? corridorPlan.optimizedDistanceKm
      : this.calculateHaversineKm(
          resolvedPickup.lat,
          resolvedPickup.lng,
          resolvedDropoff.lat,
          resolvedDropoff.lng,
        );
    const distanceKm = computedKm ?? dto.distanceKm ?? 14.5;
    const stopsCount = corridorPlan
      ? Math.max(dto.stopsCount ?? 1, corridorPlan.optimizedStops.length)
      : dto.stopsCount ?? 1;
    const authoritativeFare = this.calculateServiceFare(
      dto.serviceType,
      distanceKm,
      stopsCount,
      dto.includeInsurance ?? false,
    );
    const finalPrice = Math.max(dto.price, authoritativeFare.totalPrice);

    const orderNumber = 'AP-' + Math.floor(1000 + Math.random() * 9000);
    const waybillNumber = 'WB-LOS-' + Math.floor(100000 + Math.random() * 900000);
    const handoverOtp = Math.floor(1000 + Math.random() * 9000).toString();
    const escrowReleaseCode = dto.isEscrow
      ? Math.floor(1000 + Math.random() * 9000).toString()
      : null;

    const result = await this.prisma.$transaction(async (tx) => {
      if (paymentMethod === 'WALLET') {
        if (!user.wallet) {
          throw new BadRequestException('User wallet not found');
        }
        const deducted = await tx.wallet.updateMany({
          where: {
            id: user.wallet.id,
            balance: { gte: finalPrice },
          },
          data: {
            balance: { decrement: finalPrice },
          },
        });
        if (deducted.count === 0) {
          throw new BadRequestException('Insufficient wallet balance. Please top up your Apace Wallet.');
        }

        await tx.walletTransaction.create({
          data: {
            walletId: user.wallet.id,
            amount: finalPrice,
            isCredit: false,
            title: `Dispatch: ${dto.serviceType}`,
            subtitle: `Order #${orderNumber}`,
            reference: `ORD_PAY_${orderNumber}_${Date.now()}`,
            category: TransactionType.DISPATCH,
          },
        });
      }

      const stopCreates = corridorPlan
        ? corridorPlan.optimizedStops.map((s) => ({
            sequence: s.sequence,
            subWaybillCode: `${waybillNumber}-S${s.sequence}`,
            address: s.address,
            landmark: s.landmark || null,
            contactName: s.contactName,
            contactPhone: s.contactPhone,
            lat: s.lat,
            lng: s.lng,
            handoverOtp: Math.floor(1000 + Math.random() * 9000).toString(),
          }))
        : [
            {
              sequence: 1,
              subWaybillCode: `${waybillNumber}-S1`,
              address: dto.dropoffAddress,
              landmark: dto.dropoffLandmark || null,
              contactName: dto.dropoffContactName,
              contactPhone: dto.dropoffContactPhone,
              lat: resolvedDropoff.lat,
              lng: resolvedDropoff.lng,
              handoverOtp,
            },
          ];

      const primaryDropoff = corridorPlan
        ? corridorPlan.optimizedStops[0]
        : {
            lat: resolvedDropoff.lat,
            lng: resolvedDropoff.lng,
          };

      const order = await tx.deliveryOrder.create({
        data: {
          orderNumber,
          waybillNumber,
          senderId: userId,
          serviceType: dto.serviceType,
          status: OrderStatus.SEARCHING,
          pickupAddress: dto.pickupAddress,
          pickupLandmark: dto.pickupLandmark,
          pickupContactName: dto.pickupContactName,
          pickupContactPhone: dto.pickupContactPhone,
          pickupLat: resolvedPickup.lat,
          pickupLng: resolvedPickup.lng,
          dropoffAddress: dto.dropoffAddress,
          dropoffLandmark: dto.dropoffLandmark,
          dropoffContactName: dto.dropoffContactName,
          dropoffContactPhone: dto.dropoffContactPhone,
          dropoffLat: primaryDropoff.lat,
          dropoffLng: primaryDropoff.lng,
          distanceKm,
          packageCategory: dto.packageCategory,
          price: finalPrice,
          paymentMethod,
          isPaid: true,
          handoverOtp,
          stopsCount,
          scheduledTime: dto.scheduledTime,
          isEscrow: !!dto.isEscrow,
          escrowAmount: dto.isEscrow ? dto.escrowAmount || 0.0 : 0.0,
          escrowStatus: dto.isEscrow ? 'HELD' : null,
          escrowReleaseCode,
          stops: {
            create: stopCreates,
          },
        },
        include: {
          stops: { orderBy: { sequence: 'asc' } },
        },
      });

      return {
        message: 'Order created successfully. Searching for nearby dispatch rider...',
        order,
        corridorOptimization: corridorPlan,
      };
    });

    await this.auditService.log({
      userId,
      action: 'ORDER_CREATED',
      resource: 'DeliveryOrder',
      resourceId: result.order.id,
      metadata: { orderNumber, price: finalPrice, isEscrow: !!dto.isEscrow },
    });

    const auction = await this.dispatchEngine.startAuctionForOrder(result.order.id);

    return {
      ...result,
      auctionStatus: auction?.status || 'searching',
    };
  }

  async getOrders(userId: string, filter?: string) {
    const where: any = {
      OR: [{ senderId: userId }, { riderId: userId }],
    };
    if (filter === 'Active') {
      where.status = { notIn: [OrderStatus.DELIVERED, OrderStatus.CANCELLED] };
    } else if (filter === 'Delivered') {
      where.status = OrderStatus.DELIVERED;
    }

    return this.prisma.deliveryOrder.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        stops: { orderBy: { sequence: 'asc' } },
        rider: {
          select: {
            id: true,
            fullName: true,
            phone: true,
            riderProfile: true,
          },
        },
      },
    });
  }

  async getOrderById(orderId: string, userId: string, role: Role) {
    const order = await this.prisma.deliveryOrder.findFirst({
      where: {
        OR: [{ id: orderId }, { orderNumber: orderId }, { waybillNumber: orderId }],
      },
      include: {
        stops: { orderBy: { sequence: 'asc' } },
        rider: {
          select: {
            id: true,
            fullName: true,
            phone: true,
            riderProfile: true,
          },
        },
      },
    });

    if (!order) {
      throw new NotFoundException('Delivery order not found');
    }

    this.assertOrderAccess(order, userId, role);
    return order;
  }

  async cancelOrder(userId: string, role: Role, orderId: string) {
    const order = await this.getOrderById(orderId, userId, role);

    if (order.senderId !== userId && role !== Role.ADMIN) {
      throw new ForbiddenException('Only the sender can cancel this dispatch order');
    }

    if (order.status !== OrderStatus.SEARCHING && order.status !== OrderStatus.ASSIGNED) {
      throw new BadRequestException('Order cannot be cancelled once parcel has been picked up');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const transitioned = await tx.deliveryOrder.updateMany({
        where: {
          id: order.id,
          status: { in: [OrderStatus.SEARCHING, OrderStatus.ASSIGNED] },
        },
        data: { status: OrderStatus.CANCELLED },
      });

      if (transitioned.count === 0) {
        throw new BadRequestException('Order status changed concurrently and could not be cancelled');
      }

      if (order.paymentMethod === 'WALLET' && order.isPaid) {
        const senderWallet = await tx.wallet.findUnique({ where: { userId: order.senderId } });
        if (senderWallet) {
          await tx.wallet.update({
            where: { id: senderWallet.id },
            data: { balance: { increment: order.price } },
          });
          await tx.walletTransaction.create({
            data: {
              walletId: senderWallet.id,
              amount: order.price,
              isCredit: true,
              title: `Refund: ${order.orderNumber}`,
              subtitle: 'Cancelled dispatch refund',
              reference: `REFUND_${order.orderNumber}_${Date.now()}`,
              category: TransactionType.REFUND,
            },
          });
        }
      }

      return tx.deliveryOrder.findUnique({ where: { id: order.id } });
    });

    await this.auditService.log({
      userId,
      action: 'ORDER_CANCELLED',
      resource: 'DeliveryOrder',
      resourceId: order.id,
    });

    return { message: 'Order cancelled and refund processed', order: updated };
  }

  async tipRider(userId: string, orderId: string, dto: TipRiderDto) {
    const order = await this.prisma.deliveryOrder.findUnique({
      where: { id: orderId },
      include: { rider: { include: { wallet: true } } },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    if (order.senderId !== userId) {
      throw new ForbiddenException('Only the order sender can tip the rider');
    }

    const senderWallet = await this.prisma.wallet.findUnique({ where: { userId } });
    if (!senderWallet) {
      throw new NotFoundException('User wallet not found');
    }

    const result = await this.prisma.$transaction(async (tx) => {
      const deducted = await tx.wallet.updateMany({
        where: {
          id: senderWallet.id,
          balance: { gte: dto.amount },
        },
        data: {
          balance: { decrement: dto.amount },
        },
      });

      if (deducted.count === 0) {
        throw new BadRequestException('Insufficient wallet balance to tip rider');
      }

      await tx.walletTransaction.create({
        data: {
          walletId: senderWallet.id,
          amount: dto.amount,
          isCredit: false,
          title: `Rider Tip: ${order.rider?.fullName || 'Dispatch Rider'}`,
          subtitle: `Appreciation for order #${order.orderNumber}`,
          reference: `TIP_${order.orderNumber}_${Date.now()}`,
          category: TransactionType.TIP,
        },
      });

      if (order.rider?.wallet) {
        await tx.wallet.update({
          where: { id: order.rider.wallet.id },
          data: { balance: { increment: dto.amount } },
        });
        await tx.walletTransaction.create({
          data: {
            walletId: order.rider.wallet.id,
            amount: dto.amount,
            isCredit: true,
            title: `Customer Tip: ${order.orderNumber}`,
            subtitle: '100% direct rider tip payout',
            reference: `RIDER_TIP_${order.orderNumber}_${Date.now()}`,
            category: TransactionType.TIP,
          },
        });
      }

      const updatedOrder = await tx.deliveryOrder.update({
        where: { id: order.id },
        data: {
          tipAmount: { increment: dto.amount },
        },
      });

      return {
        message: `₦${dto.amount} tip sent successfully to rider`,
        order: updatedOrder,
      };
    });

    await this.auditService.log({
      userId,
      action: 'RIDER_TIPPED',
      resource: 'DeliveryOrder',
      resourceId: order.id,
      metadata: { amount: dto.amount },
    });

    return result;
  }

  async releaseEscrow(userId: string, role: Role, orderId: string, releaseCode?: string) {
    const order = await this.getOrderById(orderId, userId, role);

    if (!order.isEscrow || order.escrowAmount <= 0) {
      throw new BadRequestException('This order does not have active Apace Escrow funds');
    }

    if (order.escrowStatus === 'RELEASED') {
      return { message: 'Escrow already released to vendor', order };
    }

    const isAdmin = role === Role.ADMIN;
    if (!isAdmin) {
      if (!releaseCode) {
        throw new BadRequestException('4-digit buyer release code is required to release Escrow');
      }
      if (releaseCode !== order.escrowReleaseCode) {
        throw new UnauthorizedException('Invalid 4-digit escrow release code');
      }
    }

    const updatedOrder = await this.prisma.$transaction(async (tx) => {
      const claim = await tx.deliveryOrder.updateMany({
        where: {
          id: order.id,
          escrowStatus: 'HELD',
        },
        data: {
          escrowStatus: 'RELEASED',
        },
      });

      if (claim.count === 0) {
        throw new BadRequestException('Escrow funds are no longer in HELD state');
      }

      const merchantWallet = await tx.wallet.findUnique({ where: { userId: order.senderId } });
      if (merchantWallet) {
        await tx.wallet.update({
          where: { id: merchantWallet.id },
          data: { balance: { increment: order.escrowAmount } },
        });
        await tx.walletTransaction.create({
          data: {
            walletId: merchantWallet.id,
            amount: order.escrowAmount,
            isCredit: true,
            title: `Escrow Payout: ${order.orderNumber}`,
            subtitle: 'Buyer approved parcel release',
            reference: `ESCROW_REL_${order.orderNumber}_${Date.now()}`,
            category: TransactionType.ESCROW_RELEASE,
          },
        });
      }

      return tx.deliveryOrder.findUnique({ where: { id: order.id } });
    });

    await this.auditService.log({
      userId,
      action: 'ESCROW_RELEASED',
      resource: 'DeliveryOrder',
      resourceId: order.id,
      metadata: { escrowAmount: order.escrowAmount },
    });

    return {
      message: `₦${order.escrowAmount.toLocaleString()} released from Escrow to vendor wallet successfully`,
      order: updatedOrder,
    };
  }

  async generateCodUssd(userId: string, role: Role, orderId: string) {
    const order = await this.getOrderById(orderId, userId, role);
    const amount = order.escrowAmount > 0 ? order.escrowAmount : order.price;
    const refCode = Math.floor(1000 + Math.random() * 9000);

    return {
      orderNumber: order.orderNumber,
      amount,
      bankName: 'Moniepoint MFB',
      virtualAccountNumber: '8149' + Math.floor(100000 + Math.random() * 900000),
      accountName: `Apace COD - ${order.orderNumber}`,
      ussdDialString: `*5573*1*${Math.round(amount)}*${refCode}#`,
      qrPayload: `moniepoint://pay?account=8149883921&amount=${amount}&ref=${order.orderNumber}`,
      expiryMinutes: 15,
    };
  }

  async submitPod(userId: string, role: Role, orderId: string, dto: SubmitPodDto) {
    const order = await this.getOrderById(orderId, userId, role);

    if (order.riderId !== userId && order.senderId !== userId && role !== Role.ADMIN) {
      throw new ForbiddenException('Not authorized to submit proof of delivery for this order');
    }

    if (dto.handoverOtp && dto.handoverOtp !== order.handoverOtp) {
      throw new UnauthorizedException('Invalid 4-digit recipient handover OTP');
    }

    const updated = await this.prisma.deliveryOrder.update({
      where: { id: order.id },
      data: {
        hasProofOfDelivery: true,
        recipientSignature: dto.recipientSignature || order.recipientSignature,
        proofPhotoUrl: dto.proofPhotoUrl || order.proofPhotoUrl,
        status: dto.handoverOtp ? OrderStatus.DELIVERED : order.status,
        deliveredAt: dto.handoverOtp ? new Date() : order.deliveredAt,
      },
    });

    await this.auditService.log({
      userId,
      action: 'POD_SUBMITTED',
      resource: 'DeliveryOrder',
      resourceId: order.id,
      metadata: { otpConfirmed: Boolean(dto.handoverOtp) },
    });

    return { message: 'Proof of Delivery recorded', order: updated };
  }

  async getChatMessages(userId: string, role: Role, orderId: string) {
    const order = await this.getOrderById(orderId, userId, role);
    return this.prisma.chatMessage.findMany({
      where: { orderId: order.id },
      orderBy: { createdAt: 'asc' },
      include: {
        sender: {
          select: { id: true, fullName: true, role: true },
        },
      },
    });
  }

  async sendChatMessage(userId: string, role: Role, orderId: string, dto: SendChatDto) {
    const order = await this.getOrderById(orderId, userId, role);
    return this.prisma.chatMessage.create({
      data: {
        orderId: order.id,
        senderId: userId,
        senderRole: role,
        message: dto.message.trim(),
      },
      include: {
        sender: {
          select: { id: true, fullName: true, role: true },
        },
      },
    });
  }

  async openDispute(userId: string, role: Role, orderId: string, dto: OpenDisputeDto) {
    const order = await this.getOrderById(orderId, userId, role);

    const dispute = await this.prisma.dispute.create({
      data: {
        orderId: order.id,
        reporterId: userId,
        reason: dto.reason,
        description: dto.description,
        evidenceUrl: dto.evidenceUrl,
      },
    });

    await this.auditService.log({
      userId,
      action: 'DISPUTE_OPENED',
      resource: 'Dispute',
      resourceId: dispute.id,
      metadata: { orderId: order.id, reason: dto.reason },
    });

    return {
      message: 'Dispute submitted. Apace Compliance Team will review within 2 hours.',
      dispute,
    };
  }

  async getMyDisputes(userId: string) {
    return this.prisma.dispute.findMany({
      where: { reporterId: userId },
      orderBy: { createdAt: 'desc' },
      include: {
        order: {
          select: { orderNumber: true, price: true, status: true, escrowAmount: true },
        },
      },
    });
  }
}
