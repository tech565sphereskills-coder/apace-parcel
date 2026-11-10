import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { OrderStatus, Role, StopStatus, TransactionType } from '@prisma/client';

@Injectable()
export class TrackingService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
    private notificationsService: NotificationsService,
  ) {}

  private haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
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
    return r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  async verifyOrderParticipant(orderId: string, userId: string, role: string) {
    const order = await this.prisma.deliveryOrder.findFirst({
      where: {
        OR: [{ id: orderId }, { orderNumber: orderId }],
      },
      include: {
        stops: { orderBy: { sequence: 'asc' } },
      },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    if (role !== Role.ADMIN && order.senderId !== userId && order.riderId !== userId) {
      throw new ForbiddenException('Unauthorized access to order tracking room');
    }

    return order;
  }

  async processRiderTelemetry(params: {
    riderId: string;
    orderId: string;
    latitude: number;
    longitude: number;
    reportedSpeedKmh?: number;
  }) {
    const riderProfile = await this.prisma.riderProfile.findUnique({
      where: { userId: params.riderId },
    });

    let computedSpeedKmh = params.reportedSpeedKmh ?? 0;
    const now = new Date();

    if (
      riderProfile &&
      riderProfile.currentLat != null &&
      riderProfile.currentLng != null &&
      riderProfile.lastLocationAt != null
    ) {
      const distKm = this.haversineKm(
        riderProfile.currentLat,
        riderProfile.currentLng,
        params.latitude,
        params.longitude,
      );
      const elapsedSec = (now.getTime() - riderProfile.lastLocationAt.getTime()) / 1000;
      if (elapsedSec >= 2 && elapsedSec <= 900 && distKm > 0.35) {
        computedSpeedKmh = (distKm / elapsedSec) * 3600;
        if (computedSpeedKmh > 140) {
          await this.prisma.riderProfile.update({
            where: { userId: params.riderId },
            data: { spoofFlags: { increment: 1 } },
          });
          await this.auditService.log({
            userId: params.riderId,
            action: 'GEOFENCE_VELOCITY_SPOOF',
            resource: 'RiderProfile',
            resourceId: params.riderId,
            metadata: {
              orderId: params.orderId,
              computedSpeedKmh: Math.round(computedSpeedKmh),
              distKm: Math.round(distKm * 100) / 100,
              elapsedSec: Math.round(elapsedSec),
            },
          });
          return {
            rejected: true,
            reason: 'VELOCITY_SPOOF_DETECTED',
            speedKmh: Math.round(computedSpeedKmh),
            maxAllowedKmh: 140,
            message: `GPS teleport rejected (${Math.round(computedSpeedKmh)} km/h exceeds 140 km/h safety limit).`,
          };
        }
      }
    }

    if (params.reportedSpeedKmh != null && params.reportedSpeedKmh > 140) {
      if (riderProfile) {
        await this.prisma.riderProfile.update({
          where: { userId: params.riderId },
          data: { spoofFlags: { increment: 1 } },
        });
      }
      return {
        rejected: true,
        reason: 'VELOCITY_SPOOF_DETECTED',
        speedKmh: Math.round(params.reportedSpeedKmh),
        maxAllowedKmh: 140,
        message: `GPS velocity rejected (${Math.round(params.reportedSpeedKmh)} km/h exceeds 140 km/h).`,
      };
    }

    if (riderProfile) {
      await this.prisma.riderProfile.update({
        where: { userId: params.riderId },
        data: {
          currentLat: params.latitude,
          currentLng: params.longitude,
          lastLocationAt: now,
          lastSpeedKmh: Math.round(computedSpeedKmh * 10) / 10,
          isOnline: true,
        },
      });
    }

    const order = await this.prisma.deliveryOrder.findFirst({
      where: { OR: [{ id: params.orderId }, { orderNumber: params.orderId }] },
      include: { stops: { orderBy: { sequence: 'asc' } } },
    });

    let geofenceEvent: any = null;

    if (order) {
      if (
        (order.status === OrderStatus.ASSIGNED || order.status === OrderStatus.PICKED_UP) &&
        order.pickupLat != null &&
        order.pickupLng != null
      ) {
        const pickupKm = this.haversineKm(
          params.latitude,
          params.longitude,
          order.pickupLat,
          order.pickupLng,
        );
        if (pickupKm <= 0.15) {
          const isNew = order.geofenceStatus !== 'AT_PICKUP_150M';
          if (isNew) {
            await this.prisma.deliveryOrder.update({
              where: { id: order.id },
              data: { geofenceStatus: 'AT_PICKUP_150M' },
            });
            await this.notificationsService.sendPushToUser(
              order.senderId,
              `Rider Arriving for ${order.orderNumber}`,
              'Your dispatch rider is within 150m of the pickup point.',
              { orderId: order.id, zone: 'PICKUP_150M' },
            );
          }
          geofenceEvent = {
            orderId: order.id,
            orderNumber: order.orderNumber,
            zone: 'PICKUP_150M',
            distanceMeters: Math.round(pickupKm * 1000),
            triggerOtpModal: false,
            message: 'Rider entered 150m pickup geofence — Prepare parcel handover',
          };
        }
      } else if (order.status === OrderStatus.IN_TRANSIT) {
        const nextStop = order.stops.find((s) => s.status !== StopStatus.DELIVERED);
        const targetLat = nextStop?.lat ?? order.dropoffLat;
        const targetLng = nextStop?.lng ?? order.dropoffLng;

        if (targetLat != null && targetLng != null) {
          const dropKm = this.haversineKm(
            params.latitude,
            params.longitude,
            targetLat,
            targetLng,
          );
          if (dropKm <= 0.15) {
            const isNew = order.geofenceStatus !== 'AT_DROPOFF_150M';
            if (nextStop && nextStop.status === StopStatus.PENDING) {
              await this.prisma.orderStop.update({
                where: { id: nextStop.id },
                data: { status: StopStatus.ARRIVED },
              });
            }
            if (isNew) {
              await this.prisma.deliveryOrder.update({
                where: { id: order.id },
                data: { geofenceStatus: 'AT_DROPOFF_150M' },
              });
              await this.notificationsService.sendPushToUser(
                order.senderId,
                `Package Arrived (${order.orderNumber})`,
                'Rider entered 150m drop-off geofence. Confirm handover OTP.',
                { orderId: order.id, zone: 'DROPOFF_150M' },
              );
            }
            const suffix = order.escrowReleaseCode || order.orderNumber.replace('AP-', '');
            const ussdString =
              order.isEscrow && order.escrowAmount > 0
                ? `*5573*1*${Math.round(order.escrowAmount)}*${suffix}#`
                : null;
            geofenceEvent = {
              orderId: order.id,
              orderNumber: order.orderNumber,
              zone: 'DROPOFF_150M',
              distanceMeters: Math.round(dropKm * 1000),
              stopId: nextStop?.id,
              stopSequence: nextStop?.sequence,
              subWaybillCode: nextStop?.subWaybillCode,
              triggerOtpModal: true,
              isEscrow: order.isEscrow,
              escrowAmount: order.escrowAmount,
              ussdString,
              message: nextStop
                ? `Arrived within 150m of Stop #${nextStop.sequence} (${nextStop.contactName})`
                : 'Arrived within 150m of drop-off — Enter 4-digit handover OTP',
            };
          }
        }
      }
    }

    return {
      rejected: false,
      speedKmh: Math.round(computedSpeedKmh * 10) / 10,
      geofenceEvent,
    };
  }

  async saveRiderLocation(riderId: string, latitude: number, longitude: number) {
    const riderProfile = await this.prisma.riderProfile.findUnique({
      where: { userId: riderId },
    });

    if (riderProfile) {
      await this.prisma.riderProfile.update({
        where: { userId: riderId },
        data: {
          currentLat: latitude,
          currentLng: longitude,
          lastLocationAt: new Date(),
          isOnline: true,
        },
      });
    }
  }

  async verifyHandoverOtp(orderId: string, otp: string, callerUserId: string, callerRole: string) {
    const order = await this.prisma.deliveryOrder.findFirst({
      where: {
        OR: [{ id: orderId }, { orderNumber: orderId }],
      },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    if (callerRole !== Role.ADMIN && order.riderId !== callerUserId) {
      throw new ForbiddenException('Only the assigned dispatch rider can confirm handover OTP');
    }

    if (order.handoverOtp !== otp) {
      return {
        success: false,
        message: 'Invalid delivery handover OTP code',
      };
    }

    const updatedOrder = await this.prisma.$transaction(async (tx) => {
      const transitioned = await tx.deliveryOrder.updateMany({
        where: {
          id: order.id,
          status: { not: OrderStatus.DELIVERED },
        },
        data: {
          status: OrderStatus.DELIVERED,
          deliveredAt: new Date(),
        },
      });

      if (transitioned.count > 0 && order.riderId) {
        const payout = Math.round(order.price * 0.8);
        const riderWallet = await tx.wallet.findUnique({ where: { userId: order.riderId } });
        if (riderWallet) {
          await tx.wallet.update({
            where: { id: riderWallet.id },
            data: { balance: { increment: payout } },
          });
          await tx.walletTransaction.create({
            data: {
              walletId: riderWallet.id,
              amount: payout,
              isCredit: true,
              title: `Trip Payout: ${order.orderNumber}`,
              subtitle: '80% dispatch fare earned',
              reference: `RIDER_PAY_${order.orderNumber}_${Date.now()}`,
              category: TransactionType.RIDER_PAYOUT,
            },
          });
        }
        await tx.riderProfile.updateMany({
          where: { userId: order.riderId },
          data: { totalTrips: { increment: 1 } },
        });
      }

      return tx.deliveryOrder.findUnique({ where: { id: order.id } });
    });

    return {
      success: true,
      message: 'Delivery completed successfully! Handover confirmed.',
      order: updatedOrder,
    };
  }

  async persistChatMessage(orderId: string, senderId: string, senderRole: Role, message: string) {
    const order = await this.verifyOrderParticipant(orderId, senderId, senderRole);
    return this.prisma.chatMessage.create({
      data: {
        orderId: order.id,
        senderId,
        senderRole,
        message: message.trim(),
      },
      include: {
        sender: { select: { id: true, fullName: true, role: true } },
      },
    });
  }
}
