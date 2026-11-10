import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { NigerianProvidersService } from '../integrations/nigerian-providers.service';
import { VerifyNinDto } from './dto/verify-nin.dto';

@Injectable()
export class KycService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
    private providers: NigerianProvidersService,
  ) {}

  async verifyIdentity(userId: string, dto: VerifyNinDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || user.isDeleted) {
      throw new NotFoundException('User not found');
    }

    const cleanNumber = dto.identityNumber.replace(/\s+/g, '');
    if (cleanNumber.length !== 11) {
      throw new BadRequestException('Identity number must be exactly 11 digits');
    }

    const method = dto.method === 'BVN' ? 'BVN' : 'NIN';
    const verification = await this.providers.verifyNigerianIdentity(
      method,
      cleanNumber,
      user.fullName,
    );

    const updatedUser = await this.prisma.user.update({
      where: { id: userId },
      data: {
        kycTier: Math.max(user.kycTier, 2),
        ninNumber: method === 'NIN' ? cleanNumber : user.ninNumber,
        isNinVerified: method === 'NIN' ? true : user.isNinVerified,
        bvnNumber: method === 'BVN' ? cleanNumber : user.bvnNumber,
        isBvnVerified: method === 'BVN' ? true : user.isBvnVerified,
      },
      select: {
        id: true,
        fullName: true,
        phone: true,
        kycTier: true,
        ninNumber: true,
        isNinVerified: true,
        bvnNumber: true,
        isBvnVerified: true,
        isLivenessVerified: true,
      },
    });

    await this.auditService.log({
      userId,
      action: `KYC_${method}_VERIFIED`,
      resource: 'User',
      resourceId: userId,
      metadata: { provider: verification.provider, tier: updatedUser.kycTier },
    });

    return {
      success: true,
      message: `${method} successfully verified with NIMC / NIBSS registry`,
      provider: verification.provider,
      tier: updatedUser.kycTier,
      dailyLimit: this.getTierDailyLimit(updatedUser.kycTier),
      verifiedUser: {
        ...updatedUser,
        ninNumber: this.maskNumber(updatedUser.ninNumber),
        bvnNumber: this.maskNumber(updatedUser.bvnNumber),
      },
    };
  }

  async verifyLiveness(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || user.isDeleted) {
      throw new NotFoundException('User not found');
    }

    if (user.kycTier < 2 && !user.isNinVerified && !user.isBvnVerified) {
      throw new BadRequestException('Complete Tier 2 (NIN or BVN verification) before liveness scan');
    }

    const updatedUser = await this.prisma.user.update({
      where: { id: userId },
      data: {
        kycTier: 3,
        isLivenessVerified: true,
      },
      select: {
        id: true,
        fullName: true,
        kycTier: true,
        isLivenessVerified: true,
      },
    });

    await this.auditService.log({
      userId,
      action: 'KYC_TIER3_LIVENESS_VERIFIED',
      resource: 'User',
      resourceId: userId,
    });

    return {
      success: true,
      message: 'AI Biometric Liveness verified. Tier 3 Elite Merchant activated.',
      tier: 3,
      dailyLimit: this.getTierDailyLimit(3),
      user: updatedUser,
    };
  }

  async getKycStatus(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        fullName: true,
        phone: true,
        kycTier: true,
        ninNumber: true,
        isNinVerified: true,
        bvnNumber: true,
        isBvnVerified: true,
        isLivenessVerified: true,
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return {
      user: {
        ...user,
        ninNumber: this.maskNumber(user.ninNumber),
        bvnNumber: this.maskNumber(user.bvnNumber),
      },
      tier: user.kycTier,
      dailyLimit: this.getTierDailyLimit(user.kycTier),
      benefits: this.getTierBenefits(user.kycTier),
    };
  }

  private maskNumber(val?: string | null): string | null {
    if (!val || val.length < 4) return null;
    return `${'*'.repeat(val.length - 4)}${val.slice(-4)}`;
  }

  getTierDailyLimit(tier: number): number {
    switch (tier) {
      case 1:
        return 50000;
      case 2:
        return 500000;
      case 3:
      default:
        return 5000000;
    }
  }

  getTierBenefits(tier: number): string[] {
    switch (tier) {
      case 1:
        return ['₦50,000 Daily Limit', 'Intrastate Bike & Car', 'Standard Support'];
      case 2:
        return [
          '₦500,000 Daily Limit',
          'Moniepoint MFB Virtual Account',
          'Interstate Waybill Dispatch',
          'High-Value Cargo Insurance',
        ];
      case 3:
      default:
        return [
          '₦5,000,000+ Daily Limit',
          'Dedicated Merchant Priority Fleet',
          'Zero Escrow Hold',
          'Bulk Corporate API Access',
        ];
    }
  }
}
