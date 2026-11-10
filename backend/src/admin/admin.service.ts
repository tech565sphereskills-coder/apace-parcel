import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { DisputeStatus, TransactionType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';

@Injectable()
export class AdminService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
  ) {}

  async getOverview() {
    const [users, orders, openDisputes, wallets] = await Promise.all([
      this.prisma.user.count({ where: { isDeleted: false } }),
      this.prisma.deliveryOrder.count(),
      this.prisma.dispute.count({ where: { status: { in: [DisputeStatus.OPEN, DisputeStatus.INVESTIGATING] } } }),
      this.prisma.wallet.aggregate({ _sum: { balance: true } }),
    ]);

    return {
      totalUsers: users,
      totalOrders: orders,
      openDisputes,
      totalWalletLiabilityNgn: wallets._sum.balance || 0,
    };
  }

  async listDisputes() {
    return this.prisma.dispute.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        order: true,
        reporter: { select: { id: true, fullName: true, phone: true } },
      },
    });
  }

  async resolveDispute(
    adminId: string,
    disputeId: string,
    resolution: 'RESOLVED_REFUND' | 'RESOLVED_RELEASE',
    notes: string,
  ) {
    const dispute = await this.prisma.dispute.findUnique({
      where: { id: disputeId },
      include: { order: true },
    });

    if (!dispute) {
      throw new NotFoundException('Dispute not found');
    }

    if (
      dispute.status === DisputeStatus.RESOLVED_REFUND ||
      dispute.status === DisputeStatus.RESOLVED_RELEASE
    ) {
      throw new BadRequestException('Dispute is already resolved');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const resDispute = await tx.dispute.update({
        where: { id: disputeId },
        data: {
          status:
            resolution === 'RESOLVED_REFUND'
              ? DisputeStatus.RESOLVED_REFUND
              : DisputeStatus.RESOLVED_RELEASE,
          resolutionNotes: notes,
        },
      });

      if (dispute.order.isEscrow && dispute.order.escrowStatus === 'HELD') {
        const nextEscrowStatus = resolution === 'RESOLVED_REFUND' ? 'REFUNDED' : 'RELEASED';
        await tx.deliveryOrder.update({
          where: { id: dispute.order.id },
          data: { escrowStatus: nextEscrowStatus },
        });

        const beneficiaryWallet = await tx.wallet.findUnique({
          where: { userId: dispute.order.senderId },
        });
        if (beneficiaryWallet && dispute.order.escrowAmount > 0) {
          await tx.wallet.update({
            where: { id: beneficiaryWallet.id },
            data: { balance: { increment: dispute.order.escrowAmount } },
          });
          await tx.walletTransaction.create({
            data: {
              walletId: beneficiaryWallet.id,
              amount: dispute.order.escrowAmount,
              isCredit: true,
              title: `Dispute Resolution (${nextEscrowStatus}): ${dispute.order.orderNumber}`,
              subtitle: notes,
              reference: `DISP_${dispute.order.orderNumber}_${Date.now()}`,
              category:
                resolution === 'RESOLVED_REFUND'
                  ? TransactionType.REFUND
                  : TransactionType.ESCROW_RELEASE,
            },
          });
        }
      }

      return resDispute;
    });

    await this.auditService.log({
      userId: adminId,
      action: 'ADMIN_DISPUTE_RESOLVED',
      resource: 'Dispute',
      resourceId: disputeId,
      metadata: { resolution, notes },
    });

    return updated;
  }

  async updateUserKycTier(adminId: string, userId: string, tier: number) {
    if (tier < 1 || tier > 3) {
      throw new BadRequestException('KYC Tier must be 1, 2, or 3');
    }
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { kycTier: tier },
      select: { id: true, fullName: true, phone: true, kycTier: true },
    });

    await this.auditService.log({
      userId: adminId,
      action: 'ADMIN_KYC_OVERRIDE',
      resource: 'User',
      resourceId: userId,
      metadata: { tier },
    });

    return user;
  }

  async getAuditLogs() {
    return this.prisma.auditLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async listRiders() {
    return this.prisma.riderProfile.findMany({
      orderBy: { updatedAt: 'desc' },
      include: {
        user: {
          select: { id: true, fullName: true, phone: true, email: true, kycTier: true },
        },
      },
    });
  }

  async approveRider(adminId: string, userId: string, approvalStatus: 'APPROVED' | 'REJECTED') {
    const profile = await this.prisma.riderProfile.findUnique({ where: { userId } });
    if (!profile) {
      throw new NotFoundException('Rider profile not found');
    }

    const updated = await this.prisma.riderProfile.update({
      where: { userId },
      data: {
        approvalStatus,
        isVerified: approvalStatus === 'APPROVED',
      },
    });

    await this.auditService.log({
      userId: adminId,
      action: `ADMIN_RIDER_${approvalStatus}`,
      resource: 'RiderProfile',
      resourceId: userId,
    });

    return updated;
  }
}

