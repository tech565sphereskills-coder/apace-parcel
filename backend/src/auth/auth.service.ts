import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { OtpPurpose, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { NigerianProvidersService } from '../integrations/nigerian-providers.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { ResetPasswordDto, SendOtpDto, VerifyOtpDto } from './dto/otp.dto';
import { OAuthLoginDto, UpdatePreferencesDto } from './dto/oauth.dto';

interface RequestMeta {
  ipAddress?: string;
  userAgent?: string;
}

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private auditService: AuditService,
    private providers: NigerianProvidersService,
  ) {}

  async register(dto: RegisterDto, meta?: RequestMeta) {
    const cleanPhone = dto.phone.trim();
    const existingUser = await this.prisma.user.findFirst({
      where: {
        OR: [
          { phone: cleanPhone },
          dto.email ? { email: dto.email.trim().toLowerCase() } : undefined,
        ].filter(Boolean) as any,
      },
    });

    if (existingUser) {
      throw new ConflictException('User with this phone or email already exists');
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(dto.password, salt);

    let initialTier = 1;
    let verifiedNin: string | null = null;
    let isNinVerified = false;

    if (dto.ninNumber && dto.ninNumber.replace(/\s+/g, '').length === 11) {
      const cleanNin = dto.ninNumber.replace(/\s+/g, '');
      const check = await this.providers.verifyNigerianIdentity('NIN', cleanNin, dto.fullName);
      if (check.verified) {
        initialTier = 2;
        verifiedNin = cleanNin;
        isNinVerified = true;
      }
    }

    const userRole: Role = dto.role === 'RIDER' ? Role.RIDER : Role.CUSTOMER;
    const preId = crypto.randomUUID();
    const virtualAcct = await this.providers.allocateMoniepointVirtualAccount({
      userId: preId,
      fullName: dto.fullName,
      email: dto.email,
      phone: cleanPhone,
    });

    const user = await this.prisma.user.create({
      data: {
        id: preId,
        fullName: dto.fullName.trim(),
        phone: cleanPhone,
        email: dto.email?.trim().toLowerCase(),
        passwordHash,
        role: userRole,
        kycTier: initialTier,
        ninNumber: verifiedNin,
        isNinVerified,
        wallet: {
          create: {
            balance: 0.0,
            currency: 'NGN',
            virtualBankName: virtualAcct.bankName,
            virtualAccountNumber: virtualAcct.accountNumber,
            virtualAccountName: virtualAcct.accountName,
          },
        },
        riderProfile:
          userRole === Role.RIDER
            ? {
                create: {
                  vehicleType: dto.vehicleType || 'Motorcycle',
                  plateNumber: dto.plateNumber || 'LAG-PENDING',
                  isOnline: false,
                },
              }
            : undefined,
      },
      include: {
        wallet: true,
        riderProfile: true,
      },
    });

    const tokens = await this.issueSessionTokens(user.id, user.phone, user.role, dto.deviceId, meta);

    await this.auditService.log({
      userId: user.id,
      action: 'REGISTER',
      resource: 'User',
      resourceId: user.id,
      metadata: { role: user.role, kycTier: user.kycTier },
      ipAddress: meta?.ipAddress,
      userAgent: meta?.userAgent,
    });

    return {
      message: 'Account created successfully',
      token: tokens.accessToken,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: this.sanitizeUser(user),
    };
  }

  async login(dto: LoginDto, meta?: RequestMeta) {
    const identifier = dto.identifier.trim();
    const user = await this.prisma.user.findFirst({
      where: {
        isDeleted: false,
        OR: [{ phone: identifier }, { email: identifier.toLowerCase() }],
      },
      include: {
        wallet: true,
        riderProfile: true,
      },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid login credentials');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!isPasswordValid) {
      await this.auditService.log({
        userId: user.id,
        action: 'LOGIN_FAILED',
        resource: 'User',
        resourceId: user.id,
        ipAddress: meta?.ipAddress,
        userAgent: meta?.userAgent,
      });
      throw new UnauthorizedException('Invalid login credentials');
    }

    const tokens = await this.issueSessionTokens(user.id, user.phone, user.role, dto.deviceId, meta);

    await this.auditService.log({
      userId: user.id,
      action: 'LOGIN_SUCCESS',
      resource: 'User',
      resourceId: user.id,
      ipAddress: meta?.ipAddress,
      userAgent: meta?.userAgent,
    });

    return {
      message: 'Login successful',
      token: tokens.accessToken,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: this.sanitizeUser(user),
    };
  }

  async refreshTokens(refreshToken: string, meta?: RequestMeta) {
    const tokenHash = this.hashToken(refreshToken);
    const session = await this.prisma.refreshSession.findUnique({
      where: { tokenHash },
      include: { user: { include: { wallet: true, riderProfile: true } } },
    });

    if (!session || session.revokedAt || session.expiresAt <= new Date() || session.user.isDeleted) {
      throw new UnauthorizedException('Invalid or expired refresh session');
    }

    await this.prisma.refreshSession.update({
      where: { id: session.id },
      data: { revokedAt: new Date() },
    });

    const tokens = await this.issueSessionTokens(
      session.user.id,
      session.user.phone,
      session.user.role,
      session.deviceId || undefined,
      meta,
    );

    return {
      token: tokens.accessToken,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: this.sanitizeUser(session.user),
    };
  }

  async logout(userId: string, refreshToken?: string) {
    if (refreshToken) {
      const tokenHash = this.hashToken(refreshToken);
      await this.prisma.refreshSession.updateMany({
        where: { userId, tokenHash, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    } else {
      await this.prisma.refreshSession.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }
    return { success: true, message: 'Logged out successfully' };
  }

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { wallet: true, riderProfile: true },
    });

    if (!user || user.isDeleted) {
      throw new NotFoundException('User not found');
    }

    return this.sanitizeUser(user);
  }

  async sendOtp(dto: SendOtpDto) {
    const cleanPhone = dto.phone.trim();
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const codeHash = await bcrypt.hash(code, 8);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await this.prisma.otpVerification.create({
      data: {
        phone: cleanPhone,
        purpose: dto.purpose,
        codeHash,
        expiresAt,
      },
    });

    const delivery = await this.providers.sendSmsOtp(cleanPhone, code, dto.purpose);

    return {
      success: true,
      message: `Verification OTP dispatched to ${cleanPhone}`,
      expiresInSeconds: 600,
      provider: delivery.provider,
      ...(delivery.devOtp ? { devOtp: delivery.devOtp } : {}),
    };
  }

  async verifyOtp(dto: VerifyOtpDto) {
    const cleanPhone = dto.phone.trim();
    const record = await this.prisma.otpVerification.findFirst({
      where: {
        phone: cleanPhone,
        purpose: dto.purpose,
        verifiedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!record) {
      throw new BadRequestException('OTP not found or has expired. Please request a new code.');
    }

    if (record.attempts >= 5) {
      throw new UnauthorizedException('Maximum OTP verification attempts exceeded. Request a new code.');
    }

    const match = await bcrypt.compare(dto.code, record.codeHash);
    if (!match) {
      await this.prisma.otpVerification.update({
        where: { id: record.id },
        data: { attempts: { increment: 1 } },
      });
      throw new UnauthorizedException('Invalid 6-digit verification code');
    }

    await this.prisma.otpVerification.update({
      where: { id: record.id },
      data: { verifiedAt: new Date() },
    });

    if (dto.purpose === OtpPurpose.VERIFY_PHONE) {
      await this.prisma.user.updateMany({
        where: { phone: cleanPhone },
        data: { isPhoneVerified: true },
      });
    }

    return {
      success: true,
      message: 'OTP verified successfully',
    };
  }

  async resetPassword(dto: ResetPasswordDto, meta?: RequestMeta) {
    const cleanPhone = dto.phone.trim();
    await this.verifyOtp({
      phone: cleanPhone,
      purpose: OtpPurpose.RESET_PASSWORD,
      code: dto.code,
    });

    const user = await this.prisma.user.findUnique({ where: { phone: cleanPhone } });
    if (!user || user.isDeleted) {
      throw new NotFoundException('Account not found for this phone number');
    }

    const passwordHash = await bcrypt.hash(dto.newPassword, 10);
    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: user.id },
        data: { passwordHash },
      });
      await tx.refreshSession.updateMany({
        where: { userId: user.id, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    });

    await this.auditService.log({
      userId: user.id,
      action: 'PASSWORD_RESET',
      resource: 'User',
      resourceId: user.id,
      ipAddress: meta?.ipAddress,
      userAgent: meta?.userAgent,
    });

    return {
      success: true,
      message: 'Password updated successfully. Please log in again.',
    };
  }

  async deleteAccount(userId: string, meta?: RequestMeta) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { wallet: true },
    });

    if (!user || user.isDeleted) {
      throw new NotFoundException('User account not found');
    }

    if (user.wallet && user.wallet.balance > 100) {
      throw new BadRequestException(
        'Please withdraw your remaining wallet balance before closing your account',
      );
    }

    const suffix = Date.now().toString();
    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: {
          isDeleted: true,
          deletedAt: new Date(),
          fullName: 'Deleted Apace User',
          email: null,
          phone: `deleted_${suffix}_${user.id.slice(0, 8)}`,
          ninNumber: null,
          bvnNumber: null,
          transactionPinHash: null,
        },
      });
      await tx.refreshSession.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    });

    await this.auditService.log({
      userId,
      action: 'ACCOUNT_DELETED',
      resource: 'User',
      resourceId: userId,
      ipAddress: meta?.ipAddress,
      userAgent: meta?.userAgent,
    });

    return {
      success: true,
      message: 'Account permanently closed and personal identifiers removed.',
    };
  }

  async oauthLogin(dto: OAuthLoginDto, meta?: RequestMeta) {
    let verifiedEmail = dto.email.trim().toLowerCase();
    let verifiedName = dto.fullName.trim();
    let providerSub = `oauth_${dto.provider}_${verifiedEmail}`;

    const isProd = process.env.NODE_ENV === 'production';
    if (dto.provider === 'google' && dto.idToken && dto.idToken.startsWith('eyJ')) {
      const checkRes = await fetch(
        `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(dto.idToken)}`,
      );
      if (checkRes.ok) {
        const info = (await checkRes.json()) as any;
        if (info?.email) verifiedEmail = String(info.email).toLowerCase();
        if (info?.name) verifiedName = String(info.name);
        if (info?.sub) providerSub = String(info.sub);
      } else if (isProd) {
        throw new UnauthorizedException('Invalid Google OAuth token');
      }
    } else if (isProd && !dto.idToken) {
      throw new UnauthorizedException('OAuth idToken is required in production');
    }

    let user = await this.prisma.user.findFirst({
      where: { isDeleted: false, email: verifiedEmail },
      include: { wallet: true, riderProfile: true },
    });

    if (!user) {
      const preId = crypto.randomUUID();
      const syntheticPhone = '+23480' + Math.floor(10000000 + Math.random() * 89999999);
      const randomPassword = await bcrypt.hash(crypto.randomBytes(24).toString('hex'), 10);
      const virtualAcct = await this.providers.allocateMoniepointVirtualAccount({
        userId: preId,
        fullName: verifiedName,
        email: verifiedEmail,
        phone: syntheticPhone,
      });

      user = await this.prisma.user.create({
        data: {
          id: preId,
          fullName: verifiedName,
          email: verifiedEmail,
          phone: syntheticPhone,
          passwordHash: randomPassword,
          role: Role.CUSTOMER,
          kycTier: 1,
          authProvider: dto.provider,
          authProviderId: providerSub,
          wallet: {
            create: {
              balance: 0.0,
              currency: 'NGN',
              virtualBankName: virtualAcct.bankName,
              virtualAccountNumber: virtualAcct.accountNumber,
              virtualAccountName: virtualAcct.accountName,
            },
          },
        },
        include: { wallet: true, riderProfile: true },
      });
    } else if (!user.authProvider) {
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: { authProvider: dto.provider, authProviderId: providerSub },
        include: { wallet: true, riderProfile: true },
      });
    }

    const tokens = await this.issueSessionTokens(
      user.id,
      user.phone,
      user.role,
      dto.deviceId,
      meta,
    );

    await this.auditService.log({
      userId: user.id,
      action: `OAUTH_LOGIN_${dto.provider.toUpperCase()}`,
      resource: 'User',
      resourceId: user.id,
      ipAddress: meta?.ipAddress,
      userAgent: meta?.userAgent,
    });

    return {
      message: `Signed in with ${dto.provider}`,
      token: tokens.accessToken,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: this.sanitizeUser(user),
    };
  }

  async updatePreferences(userId: string, dto: UpdatePreferencesDto) {
    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: {
        notifyWhatsapp: dto.notifyWhatsapp ?? undefined,
        notifySms: dto.notifySms ?? undefined,
        notifyPush: dto.notifyPush ?? undefined,
      },
      include: { wallet: true, riderProfile: true },
    });

    return {
      success: true,
      user: this.sanitizeUser(updated),
    };
  }

  private async issueSessionTokens(
    userId: string,
    phone: string,
    role: Role,
    deviceId?: string,
    meta?: RequestMeta,
  ) {
    const accessToken = this.jwtService.sign({
      sub: userId,
      phone,
      role,
    });

    const refreshToken = crypto.randomBytes(48).toString('hex');
    const tokenHash = this.hashToken(refreshToken);
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

    await this.prisma.refreshSession.create({
      data: {
        userId,
        tokenHash,
        deviceId,
        ipAddress: meta?.ipAddress,
        userAgent: meta?.userAgent,
        expiresAt,
      },
    });

    return { accessToken, refreshToken };
  }

  private hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  private maskIdentity(val?: string | null): string | null {
    if (!val || val.length < 4) return null;
    return `${'*'.repeat(val.length - 4)}${val.slice(-4)}`;
  }

  sanitizeUser(user: any) {
    const {
      passwordHash,
      transactionPinHash,
      pinAttempts,
      pinLockedUntil,
      ninNumber,
      bvnNumber,
      ...rest
    } = user;

    return {
      ...rest,
      ninNumber: this.maskIdentity(ninNumber),
      bvnNumber: this.maskIdentity(bvnNumber),
      hasTransactionPin: Boolean(transactionPinHash),
    };
  }
}
