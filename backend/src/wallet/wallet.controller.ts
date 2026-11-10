import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Post,
  Query,
  RawBodyRequest,
  Req,
  Request,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { WalletService } from './wallet.service';
import { FundWalletDto } from './dto/fund-wallet.dto';
import { WithdrawDto } from './dto/withdraw.dto';
import { MoniepointWebhookDto } from './dto/moniepoint-webhook.dto';
import { SetupPinDto } from './dto/setup-pin.dto';
import { VerifyPinDto } from './dto/verify-pin.dto';
import { ResolveAccountDto } from './dto/resolve-account.dto';
import { ResetPinDto } from './dto/reset-pin.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RateLimit } from '../common/decorators/rate-limit.decorator';
import { RateLimitGuard } from '../common/guards/rate-limit.guard';

@ApiTags('Wallet & Payments')
@UseGuards(RateLimitGuard)
@Controller('wallet')
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  @Get()
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Get current wallet balance and dedicated Moniepoint MFB account details' })
  async getWallet(@Request() req: any) {
    return this.walletService.getWallet(req.user.id);
  }

  @Get('transactions')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Get wallet transaction activity with optional filter' })
  async getTransactions(@Request() req: any, @Query('category') category?: string) {
    return this.walletService.getTransactions(req.user.id, category);
  }

  @Post('resolve-account')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @RateLimit(15, 60)
  @ApiOperation({ summary: 'Resolve Nigerian NUBAN account holder name before bank withdrawal' })
  async resolveAccount(@Body() dto: ResolveAccountDto) {
    return this.walletService.resolveBankAccount(dto);
  }

  @Post('fund')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @RateLimit(10, 60)
  @ApiOperation({ summary: 'Fund wallet with verified Paystack reference or transfer' })
  async fundWallet(@Request() req: any, @Body() dto: FundWalletDto) {
    return this.walletService.fundWallet(req.user.id, dto);
  }

  @Post('withdraw')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @RateLimit(5, 60)
  @ApiOperation({ summary: 'Withdraw wallet balance to any Nigerian bank with 4-digit PIN and KYC limit check' })
  async withdraw(@Request() req: any, @Body() dto: WithdrawDto) {
    return this.walletService.withdraw(req.user.id, dto);
  }

  @Get('pin/status')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Check if user has 4-digit transaction PIN set and lockout state' })
  async getPinStatus(@Request() req: any) {
    return this.walletService.getPinStatus(req.user.id);
  }

  @Post('pin/setup')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @RateLimit(5, 60)
  @ApiOperation({ summary: 'Set or update 4-digit secret transaction PIN' })
  async setupPin(@Request() req: any, @Body() dto: SetupPinDto) {
    return this.walletService.setupPin(req.user.id, dto);
  }

  @Post('pin/verify')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @RateLimit(10, 60)
  @ApiOperation({ summary: 'Verify 4-digit transaction PIN before authorizing sensitive actions' })
  async verifyPin(@Request() req: any, @Body() dto: VerifyPinDto) {
    return this.walletService.verifyPin(req.user.id, dto);
  }

  @Post('pin/reset')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @RateLimit(5, 60)
  @ApiOperation({ summary: 'Reset 4-digit transaction PIN using verified SMS OTP' })
  async resetPin(@Request() req: any, @Body() dto: ResetPinDto) {
    return this.walletService.resetPinWithOtp(req.user.id, dto);
  }

  @Post('webhook/moniepoint')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Automated deposit webhook from Moniepoint MFB with strict HMAC-SHA512 verification' })
  @ApiHeader({ name: 'x-moniepoint-signature', required: true, description: 'HMAC-SHA512 signature' })
  @ApiResponse({ status: 200, description: 'Virtual account deposit processed' })
  async moniepointWebhook(
    @Body() dto: MoniepointWebhookDto,
    @Headers('x-moniepoint-signature') signature: string | undefined,
    @Req() req: RawBodyRequest<any>,
  ) {
    const rawBody = req?.rawBody ? req.rawBody.toString('utf8') : undefined;
    return this.walletService.handleMoniepointDepositWebhook(dto, signature, rawBody);
  }

  @Post('webhook/paystack')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Automated charge.success webhook from Paystack with HMAC-SHA512 verification' })
  @ApiHeader({ name: 'x-paystack-signature', required: true, description: 'HMAC-SHA512 signature' })
  async paystackWebhook(
    @Body() payload: any,
    @Headers('x-paystack-signature') signature: string | undefined,
    @Req() req: RawBodyRequest<any>,
  ) {
    const rawBody = req?.rawBody ? req.rawBody.toString('utf8') : undefined;
    return this.walletService.handlePaystackWebhook(payload, signature, rawBody);
  }
}
