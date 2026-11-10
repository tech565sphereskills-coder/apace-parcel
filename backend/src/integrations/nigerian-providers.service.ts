import { Injectable, BadRequestException, ServiceUnavailableException, Logger } from '@nestjs/common';

@Injectable()
export class NigerianProvidersService {
  private readonly logger = new Logger(NigerianProvidersService.name);

  private get isProd(): boolean {
    return process.env.NODE_ENV === 'production';
  }

  private getConfiguredKey(name: string): string | undefined {
    const val = process.env[name]?.trim();
    if (!val || val.toLowerCase().includes('placeholder')) {
      return undefined;
    }
    return val;
  }

  async sendSmsOtp(phone: string, code: string, purpose: string) {
    const apiKey = this.getConfiguredKey('TERMII_API_KEY');
    const senderId = process.env.TERMII_SENDER_ID || 'ApaceNG';
    const message = `Your Apace Parcel ${purpose} verification code is ${code}. Valid for 10 minutes. Do not share with anyone.`;

    if (apiKey) {
      const normalized = phone.replace(/\s+/g, '').replace(/^\+/, '');
      const response = await fetch('https://api.ng.termii.com/api/sms/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          to: normalized,
          from: senderId,
          sms: message,
          type: 'plain',
          channel: 'dnd',
          api_key: apiKey,
        }),
      });
      if (!response.ok) {
        const body = await response.text();
        this.logger.error(`Termii SMS error: ${body}`);
        throw new ServiceUnavailableException('Unable to dispatch SMS OTP via Termii');
      }
      const data = (await response.json()) as any;
      return { delivered: true, provider: 'termii', messageId: data.message_id };
    }

    if (this.isProd) {
      throw new ServiceUnavailableException('TERMII_API_KEY is required in production');
    }

    this.logger.log(`[SANDBOX TERMII SMS] To: ${phone} | OTP: ${code}`);
    return { delivered: true, provider: 'termii_sandbox', devOtp: code };
  }

  async allocateMoniepointVirtualAccount(params: {
    userId: string;
    fullName: string;
    email?: string | null;
    phone: string;
  }) {
    const apiKey = this.getConfiguredKey('MONIEPOINT_API_KEY');
    const contractCode = this.getConfiguredKey('MONIEPOINT_CONTRACT_CODE');
    const baseUrl = process.env.MONIEPOINT_BASE_URL || 'https://api.monnify.com';

    if (apiKey && contractCode) {
      const response = await fetch(`${baseUrl}/api/v2/bank-transfer/reserved-accounts`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          accountReference: `APACE_${params.userId}`,
          accountName: `Apace / ${params.fullName}`,
          currencyCode: 'NGN',
          contractCode,
          customerEmail: params.email || `${params.userId}@users.apace.ng`,
          customerName: params.fullName,
          getAllAvailableBanks: false,
          preferredBanks: ['50515'],
        }),
      });

      if (response.ok) {
        const payload = (await response.json()) as any;
        const acct = payload?.responseBody?.accounts?.[0];
        if (acct?.accountNumber) {
          return {
            bankName: acct.bankName || 'Moniepoint MFB',
            accountNumber: acct.accountNumber,
            accountName: acct.accountName || `Apace / ${params.fullName}`,
            provider: 'moniepoint_live',
          };
        }
      }
      this.logger.warn('Moniepoint reserved account API failed; falling back to deterministic NUBAN');
    }

    const digits = params.phone.replace(/\D/g, '').slice(-8).padStart(8, '4');
    return {
      bankName: 'Moniepoint MFB',
      accountNumber: `81${digits}`,
      accountName: `Apace / ${params.fullName}`,
      provider: 'moniepoint_sandbox',
    };
  }

  async verifyPaystackTransaction(reference: string, expectedAmountNaira: number) {
    const secret = this.getConfiguredKey('PAYSTACK_SECRET_KEY');
    if (secret) {
      const response = await fetch(`https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`, {
        headers: { Authorization: `Bearer ${secret}` },
      });
      if (!response.ok) {
        throw new BadRequestException('Failed to verify payment reference with Paystack');
      }
      const data = (await response.json()) as any;
      if (!data.status || data.data?.status !== 'success') {
        throw new BadRequestException('Paystack payment has not succeeded');
      }
      const paidNaira = (data.data?.amount || 0) / 100;
      if (paidNaira < expectedAmountNaira) {
        throw new BadRequestException('Paid amount does not match requested wallet deposit');
      }
      return { verified: true, provider: 'paystack_live', amount: paidNaira };
    }

    if (this.isProd) {
      throw new ServiceUnavailableException('PAYSTACK_SECRET_KEY is required in production');
    }

    return { verified: true, provider: 'paystack_sandbox', amount: expectedAmountNaira };
  }

  async resolveBankAccount(accountNumber: string, bankCode: string) {
    if (!/^\d{10}$/.test(accountNumber)) {
      throw new BadRequestException('NUBAN account number must be 10 digits');
    }

    const secret = this.getConfiguredKey('PAYSTACK_SECRET_KEY');
    if (secret) {
      const response = await fetch(
        `https://api.paystack.co/bank/resolve?account_number=${accountNumber}&bank_code=${encodeURIComponent(bankCode)}`,
        { headers: { Authorization: `Bearer ${secret}` } },
      );
      if (!response.ok) {
        throw new BadRequestException('Could not resolve bank account name');
      }
      const data = (await response.json()) as any;
      if (!data.status || !data.data?.account_name) {
        throw new BadRequestException('Invalid NUBAN account number or bank code');
      }
      return {
        accountNumber: data.data.account_number,
        accountName: data.data.account_name,
        bankCode,
        provider: 'paystack_live',
      };
    }

    return {
      accountNumber,
      accountName: 'MICHAEL OGUNDIMU',
      bankCode,
      provider: 'nibss_sandbox',
    };
  }

  async initiateBankTransfer(params: {
    amountNaira: number;
    bankName: string;
    bankCode?: string;
    accountNumber: string;
    accountName?: string;
    reference: string;
  }) {
    const secret = this.getConfiguredKey('PAYSTACK_SECRET_KEY');
    if (secret) {
      const bankCode = params.bankCode || '044';
      const recipRes = await fetch('https://api.paystack.co/transferrecipient', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${secret}`,
        },
        body: JSON.stringify({
          type: 'nuban',
          name: params.accountName || 'Apace User',
          account_number: params.accountNumber,
          bank_code: bankCode,
          currency: 'NGN',
        }),
      });
      if (!recipRes.ok) {
        const errText = await recipRes.text();
        this.logger.error(`Paystack transfer recipient error: ${errText}`);
        throw new ServiceUnavailableException('Unable to create bank transfer recipient');
      }
      const recipData = (await recipRes.json()) as any;
      const recipientCode = recipData?.data?.recipient_code;

      const txRes = await fetch('https://api.paystack.co/transfer', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${secret}`,
        },
        body: JSON.stringify({
          source: 'balance',
          reason: `Apace Wallet Withdrawal (${params.reference})`,
          amount: Math.round(params.amountNaira * 100),
          recipient: recipientCode,
          reference: params.reference,
        }),
      });
      if (!txRes.ok) {
        const errText = await txRes.text();
        this.logger.error(`Paystack transfer dispatch error: ${errText}`);
        throw new ServiceUnavailableException('Unable to execute Paystack bank transfer');
      }
      const txData = (await txRes.json()) as any;
      return {
        initiated: true,
        provider: 'paystack_live',
        transferReference: txData?.data?.transfer_code || params.reference,
      };
    }

    if (this.isProd) {
      throw new ServiceUnavailableException('PAYSTACK_SECRET_KEY is required for production payouts');
    }

    return {
      initiated: true,
      provider: 'nip_sandbox',
      transferReference: params.reference,
    };
  }

  async verifyNigerianIdentity(method: 'NIN' | 'BVN', identityNumber: string, fullName: string) {
    const clean = identityNumber.replace(/\s+/g, '');
    if (!/^\d{11}$/.test(clean)) {
      throw new BadRequestException(`${method} must consist of exactly 11 numeric digits`);
    }

    const dojahAppId = this.getConfiguredKey('DOJAH_APP_ID');
    const dojahKey = this.getConfiguredKey('DOJAH_PRIVATE_KEY');

    if (dojahAppId && dojahKey) {
      const endpoint =
        method === 'NIN'
          ? `https://api.dojah.io/api/v1/kyc/nin?nin=${clean}`
          : `https://api.dojah.io/api/v1/kyc/bvn?bvn=${clean}`;
      const response = await fetch(endpoint, {
        headers: {
          AppId: dojahAppId,
          Authorization: dojahKey,
        },
      });
      if (!response.ok) {
        throw new BadRequestException(`${method} verification failed against NIMC/NIBSS registry`);
      }
      const payload = (await response.json()) as any;
      return {
        verified: true,
        provider: 'dojah_live',
        matchedName: payload?.entity?.first_name ? `${payload.entity.first_name} ${payload.entity.last_name}` : fullName,
      };
    }

    if (this.isProd) {
      throw new ServiceUnavailableException('DOJAH_APP_ID and DOJAH_PRIVATE_KEY are required in production');
    }

    return {
      verified: true,
      provider: 'nimc_sandbox',
      matchedName: fullName,
    };
  }
}
