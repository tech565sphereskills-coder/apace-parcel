import {
  Injectable,
  BadRequestException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { NigerianProvidersService } from '../integrations/nigerian-providers.service';
import { FundWalletDto } from './dto/fund-wallet.dto';
import { WithdrawDto } from './dto/withdraw.dto';
import { MoniepointWebhookDto } from './dto/moniepoint-webhook.dto';
import { SetupPinDto } from './dto/setup-pin.dto';
import { VerifyPinDto } from './dto/verify-pin.dto';
import { ResolveAccountDto } from './dto/resolve-account.dto';
import { ResetPinDto } from './dto/reset-pin.dto';
import { OtpPurpose, TransactionType } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';

@Injectable()
export class WalletService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
    private providers: NigerianProvidersService,
  ) {}

  async getWallet(userId: string) {
    const wallet = await this.prisma.wallet.findUnique({
      where: { userId },
      include: {
        transactions: {
          orderBy: { createdAt: 'desc' },
          take: 25,
        },
      },
    });

    if (!wallet) {
      throw new NotFoundException('Wallet not found for this user');
    }

    return wallet;
  }

  async getTransactions(userId: string, category?: string) {
    const wallet = await this.prisma.wallet.findUnique({ where: { userId } });
    if (!wallet) {
      throw new NotFoundException('Wallet not found');
    }

    let filterCategory: TransactionType | undefined;
    if (category && category !== 'All') {
      const catMap: Record<string, TransactionType> = {
        'Top-Ups': TransactionType.TOPUP,
        Dispatches: TransactionType.DISPATCH,
        Tips: TransactionType.TIP,
        Withdrawals: TransactionType.WITHDRAWAL,
        Escrow: TransactionType.ESCROW_RELEASE,
        Payouts: TransactionType.RIDER_PAYOUT,
        Refunds: TransactionType.REFUND,
      };
      filterCategory = catMap[category];
    }

    return this.prisma.walletTransaction.findMany({
      where: {
        walletId: wallet.id,
        category: filterCategory,
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async resolveBankAccount(dto: ResolveAccountDto) {
    return this.providers.resolveBankAccount(dto.accountNumber, dto.bankCode);
  }

  async fundWallet(userId: string, dto: FundWalletDto) {
    const wallet = await this.prisma.wallet.findUnique({ where: { userId } });
    if (!wallet) {
      throw new NotFoundException('Wallet not found');
    }

    const reference =
      dto.paymentReference ||
      'TOPUP_' + Date.now() + '_' + Math.floor(Math.random() * 10000);

    const existing = await this.prisma.walletTransaction.findUnique({
      where: { reference },
    });
    if (existing) {
      return {
        message: 'Transaction already credited',
        wallet,
        transaction: existing,
      };
    }

    if (process.env.NODE_ENV === 'production' && !dto.paymentReference) {
      throw new BadRequestException('Verified Paystack paymentReference is required in production');
    }

    if (dto.paymentReference || dto.method.toLowerCase().includes('paystack')) {
      await this.providers.verifyPaystackTransaction(reference, dto.amount);
    }

    const result = await this.prisma.$transaction(async (tx) => {
      const updatedWallet = await tx.wallet.update({
        where: { id: wallet.id },
        data: {
          balance: { increment: dto.amount },
        },
      });

      const transaction = await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          amount: dto.amount,
          isCredit: true,
          title: `Top Up via ${dto.method}`,
          subtitle: 'Verified wallet deposit',
          reference,
          category: TransactionType.TOPUP,
        },
      });

      return {
        message: 'Wallet funded successfully',
        wallet: updatedWallet,
        transaction,
      };
    });

    await this.auditService.log({
      userId,
      action: 'WALLET_TOPUP',
      resource: 'Wallet',
      resourceId: wallet.id,
      metadata: { amount: dto.amount, method: dto.method, reference },
    });

    return result;
  }

  async setupPin(userId: string, dto: SetupPinDto) {
    const saltRounds = 10;
    const pinHash = await bcrypt.hash(dto.pin, saltRounds);

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        transactionPinHash: pinHash,
        pinAttempts: 0,
        pinLockedUntil: null,
      },
    });

    await this.auditService.log({
      userId,
      action: 'TRANSACTION_PIN_SET',
      resource: 'User',
      resourceId: userId,
    });

    return {
      success: true,
      message: '4-digit transaction PIN set successfully',
    };
  }

  async resetPinWithOtp(userId: string, dto: ResetPinDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    const otpRecord = await this.prisma.otpVerification.findFirst({
      where: {
        phone: user.phone,
        purpose: OtpPurpose.RESET_PIN,
        verifiedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otpRecord || otpRecord.attempts >= 5) {
      throw new BadRequestException('Valid PIN reset OTP required');
    }

    const validOtp = await bcrypt.compare(dto.otpCode, otpRecord.codeHash);
    if (!validOtp) {
      await this.prisma.otpVerification.update({
        where: { id: otpRecord.id },
        data: { attempts: { increment: 1 } },
      });
      throw new UnauthorizedException('Invalid 6-digit OTP code');
    }

    const pinHash = await bcrypt.hash(dto.newPin, 10);
    await this.prisma.$transaction(async (tx) => {
      await tx.otpVerification.update({
        where: { id: otpRecord.id },
        data: { verifiedAt: new Date() },
      });
      await tx.user.update({
        where: { id: userId },
        data: {
          transactionPinHash: pinHash,
          pinAttempts: 0,
          pinLockedUntil: null,
        },
      });
    });

    await this.auditService.log({
      userId,
      action: 'TRANSACTION_PIN_RESET',
      resource: 'User',
      resourceId: userId,
    });

    return { success: true, message: 'Transaction PIN reset successfully' };
  }

  async verifyPin(userId: string, dto: VerifyPinDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        transactionPinHash: true,
        pinAttempts: true,
        pinLockedUntil: true,
      },
    });

    if (!user || !user.transactionPinHash) {
      throw new BadRequestException('Transaction PIN not configured. Please set a 4-digit PIN first.');
    }

    const now = new Date();
    if (user.pinLockedUntil && user.pinLockedUntil > now) {
      const remainingMs = user.pinLockedUntil.getTime() - now.getTime();
      const remainingMinutes = Math.ceil(remainingMs / (60 * 1000));
      throw new UnauthorizedException(
        `Wallet locked due to repeated incorrect PIN attempts. Try again in ${remainingMinutes} minute(s).`,
      );
    }

    const isMatch = await bcrypt.compare(dto.pin, user.transactionPinHash);
    if (!isMatch) {
      const updatedAttempts = user.pinAttempts + 1;
      if (updatedAttempts >= 3) {
        const lockUntil = new Date(Date.now() + 30 * 60 * 1000);
        await this.prisma.user.update({
          where: { id: userId },
          data: {
            pinAttempts: updatedAttempts,
            pinLockedUntil: lockUntil,
          },
        });
        await this.auditService.log({
          userId,
          action: 'TRANSACTION_PIN_LOCKOUT',
          resource: 'User',
          resourceId: userId,
        });
        throw new UnauthorizedException(
          'Incorrect PIN. Maximum 3 attempts exceeded. Wallet locked for 30 minutes.',
        );
      } else {
        await this.prisma.user.update({
          where: { id: userId },
          data: { pinAttempts: updatedAttempts },
        });
        const remaining = 3 - updatedAttempts;
        throw new UnauthorizedException(
          `Incorrect PIN. ${remaining} attempt(s) remaining before wallet lockout.`,
        );
      }
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        pinAttempts: 0,
        pinLockedUntil: null,
      },
    });

    return { valid: true, message: 'PIN verified successfully' };
  }

  async getPinStatus(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        transactionPinHash: true,
        pinAttempts: true,
        pinLockedUntil: true,
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const now = new Date();
    const isLocked = !!(user.pinLockedUntil && user.pinLockedUntil > now);
    let remainingMinutes = 0;
    if (isLocked && user.pinLockedUntil) {
      remainingMinutes = Math.ceil((user.pinLockedUntil.getTime() - now.getTime()) / (60 * 1000));
    }

    return {
      hasPin: !!user.transactionPinHash,
      isLocked,
      remainingMinutes,
      attemptsRemaining: Math.max(0, 3 - user.pinAttempts),
    };
  }

  async withdraw(userId: string, dto: WithdrawDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { transactionPinHash: true, kycTier: true },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (!user.transactionPinHash) {
      throw new BadRequestException('Please set your 4-digit transaction PIN before withdrawing');
    }

    if (!dto.pin) {
      throw new BadRequestException('4-digit transaction PIN is required to authorize withdrawals');
    }

    await this.verifyPin(userId, { pin: dto.pin });

    const wallet = await this.prisma.wallet.findUnique({ where: { userId } });
    if (!wallet) {
      throw new NotFoundException('Wallet not found');
    }

    const dailyLimit = user.kycTier === 1 ? 50000 : user.kycTier === 2 ? 500000 : 5000000;
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);

    const todayWithdrawals = await this.prisma.walletTransaction.aggregate({
      where: {
        walletId: wallet.id,
        category: TransactionType.WITHDRAWAL,
        createdAt: { gte: startOfDay },
      },
      _sum: { amount: true },
    });

    const usedToday = todayWithdrawals._sum.amount || 0;
    if (usedToday + dto.amount > dailyLimit) {
      throw new BadRequestException(
        `Withdrawal exceeds your KYC Tier ${user.kycTier} daily limit of ₦${dailyLimit.toLocaleString()}`,
      );
    }

    const reference = 'WTH_' + Date.now() + '_' + Math.floor(Math.random() * 10000);

    const transfer = await this.providers.initiateBankTransfer({
      amountNaira: dto.amount,
      bankName: dto.bankName,
      accountNumber: dto.accountNumber,
      reference,
    });

    const result = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.wallet.updateMany({
        where: {
          id: wallet.id,
          balance: { gte: dto.amount },
        },
        data: {
          balance: { decrement: dto.amount },
        },
      });

      if (updated.count === 0) {
        throw new BadRequestException('Insufficient wallet balance');
      }

      const updatedWallet = await tx.wallet.findUnique({ where: { id: wallet.id } });
      const transaction = await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          amount: dto.amount,
          isCredit: false,
          title: `Withdrawal to ${dto.bankName}`,
          subtitle: `Account: ${dto.accountNumber}`,
          reference,
          category: TransactionType.WITHDRAWAL,
        },
      });

      return {
        message: `Withdrawal of ₦${dto.amount} to ${dto.bankName} initiated successfully`,
        provider: transfer.provider,
        wallet: updatedWallet,
        transaction,
      };
    });

    await this.auditService.log({
      userId,
      action: 'WALLET_WITHDRAWAL',
      resource: 'Wallet',
      resourceId: wallet.id,
      metadata: {
        amount: dto.amount,
        bankName: dto.bankName,
        accountNumber: dto.accountNumber,
        reference,
      },
    });

    return result;
  }

  verifyHmacSignature(rawPayload: string, signature: string | undefined, secretKey: string): boolean {
    if (!signature || !rawPayload) {
      return false;
    }
    const hash = crypto.createHmac('sha512', secretKey).update(rawPayload).digest('hex');
    const hashBuffer = Buffer.from(hash, 'utf8');
    const signatureBuffer = Buffer.from(signature, 'utf8');
    if (hashBuffer.length !== signatureBuffer.length) {
      return false;
    }
    return crypto.timingSafeEqual(hashBuffer, signatureBuffer);
  }

  async handleMoniepointDepositWebhook(
    dto: MoniepointWebhookDto,
    signature?: string,
    rawBody?: string,
  ) {
    if (!rawBody || !signature) {
      throw new UnauthorizedException('Missing Moniepoint webhook signature or raw payload');
    }

    const webhookSecret =
      process.env.MONIEPOINT_WEBHOOK_SECRET || 'moniepoint_test_secret_apace_ng_2026';

    const isValid = this.verifyHmacSignature(rawBody, signature, webhookSecret);
    if (!isValid) {
      throw new UnauthorizedException('Invalid Moniepoint HMAC signature');
    }

    if (dto.amount <= 0) {
      throw new BadRequestException('Webhook amount must be positive');
    }

    const cleanAccount = dto.accountNumber.replace(/\s+/g, '');
    const wallet = await this.prisma.wallet.findFirst({
      where: {
        virtualAccountNumber: {
          contains: cleanAccount,
        },
      },
    });

    if (!wallet) {
      throw new NotFoundException('Virtual account not matched to any wallet');
    }

    const existingTx = await this.prisma.walletTransaction.findUnique({
      where: { reference: dto.transactionReference },
    });

    if (existingTx) {
      return { status: 'already_processed' };
    }

    const result = await this.prisma.$transaction(async (tx) => {
      const updatedWallet = await tx.wallet.update({
        where: { id: wallet.id },
        data: {
          balance: { increment: dto.amount },
        },
      });

      const transaction = await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          amount: dto.amount,
          isCredit: true,
          title: 'Top Up via Moniepoint Transfer',
          subtitle: `From: ${dto.senderName}`,
          reference: dto.transactionReference,
          category: TransactionType.TOPUP,
        },
      });

      return {
        status: 'credited',
        newBalance: updatedWallet.balance,
        transaction,
      };
    });

    await this.auditService.log({
      userId: wallet.userId,
      action: 'MONIEPOINT_WEBHOOK_CREDITED',
      resource: 'Wallet',
      resourceId: wallet.id,
      metadata: { amount: dto.amount, reference: dto.transactionReference },
    });

    return result;
  }

  async handlePaystackWebhook(payload: any, signature?: string, rawBody?: string) {
    if (!rawBody || !signature) {
      throw new UnauthorizedException('Missing Paystack webhook signature or raw payload');
    }

    const secret = process.env.PAYSTACK_SECRET_KEY || 'paystack_test_secret_apace_ng_2026';
    if (!this.verifyHmacSignature(rawBody, signature, secret)) {
      throw new UnauthorizedException('Invalid Paystack HMAC-SHA512 signature');
    }

    if (payload?.event !== 'charge.success') {
      return { status: 'ignored', event: payload?.event };
    }

    const ref = payload?.data?.reference;
    const email = payload?.data?.customer?.email;
    const amountNaira = Number(payload?.data?.amount || 0) / 100;

    if (!ref || amountNaira <= 0 || !email) {
      return { status: 'invalid_payload' };
    }

    const existing = await this.prisma.walletTransaction.findUnique({ where: { reference: ref } });
    if (existing) {
      return { status: 'already_processed' };
    }

    const user = await this.prisma.user.findUnique({
      where: { email },
      include: { wallet: true },
    });

    if (!user || !user.wallet) {
      return { status: 'user_not_found' };
    }

    const wallet = user.wallet;
    await this.prisma.$transaction(async (tx) => {
      await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: { increment: amountNaira } },
      });
      await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          amount: amountNaira,
          isCredit: true,
          title: 'Top Up via Paystack',
          subtitle: 'Verified webhook payment',
          reference: ref,
          category: TransactionType.TOPUP,
        },
      });
    });

    await this.auditService.log({
      userId: user.id,
      action: 'PAYSTACK_WEBHOOK_CREDITED',
      resource: 'Wallet',
      resourceId: wallet.id,
      metadata: { amount: amountNaira, reference: ref },
    });

    return { status: 'credited', reference: ref };
  }
}
