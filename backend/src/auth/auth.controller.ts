import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Patch,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto, ResetPasswordDto, SendOtpDto, VerifyOtpDto } from './dto/otp.dto';
import { OAuthLoginDto, UpdatePreferencesDto } from './dto/oauth.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RateLimit } from '../common/decorators/rate-limit.decorator';
import { RateLimitGuard } from '../common/guards/rate-limit.guard';

@ApiTags('Authentication')
@UseGuards(RateLimitGuard)
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @RateLimit(10, 60)
  @ApiOperation({ summary: 'Register customer or rider account with optional KYC Tier 2' })
  @ApiResponse({ status: 201, description: 'Account created with dedicated Moniepoint wallet' })
  async register(@Body() dto: RegisterDto, @Request() req: any) {
    return this.authService.register(dto, {
      ipAddress: req.ip,
      userAgent: req.headers['user-agent'],
    });
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @RateLimit(10, 60)
  @ApiOperation({ summary: 'Log in with phone/email and password' })
  @ApiResponse({ status: 200, description: 'Access JWT, refresh token, and sanitized profile' })
  async login(@Body() dto: LoginDto, @Request() req: any) {
    return this.authService.login(dto, {
      ipAddress: req.ip,
      userAgent: req.headers['user-agent'],
    });
  }

  @Post('oauth')
  @HttpCode(HttpStatus.OK)
  @RateLimit(15, 60)
  @ApiOperation({ summary: 'Sign in or register using Google / Apple OAuth token' })
  async oauthLogin(@Body() dto: OAuthLoginDto, @Request() req: any) {
    return this.authService.oauthLogin(dto, {
      ipAddress: req.ip,
      userAgent: req.headers['user-agent'],
    });
  }

  @Patch('preferences')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Update WhatsApp, SMS, and push notification preferences' })
  async updatePreferences(@Request() req: any, @Body() dto: UpdatePreferencesDto) {
    return this.authService.updatePreferences(req.user.id, dto);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @RateLimit(20, 60)
  @ApiOperation({ summary: 'Rotate refresh token for a fresh access + refresh token pair' })
  async refresh(@Body() dto: RefreshTokenDto, @Request() req: any) {
    return this.authService.refreshTokens(dto.refreshToken, {
      ipAddress: req.ip,
      userAgent: req.headers['user-agent'],
    });
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Revoke active refresh session' })
  async logout(@Request() req: any, @Body() body: { refreshToken?: string }) {
    return this.authService.logout(req.user.id, body?.refreshToken);
  }

  @Get('me')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Fetch sanitized user profile, KYC status, and wallet summary' })
  async me(@Request() req: any) {
    return this.authService.getProfile(req.user.id);
  }

  @Post('otp/send')
  @HttpCode(HttpStatus.OK)
  @RateLimit(3, 60)
  @ApiOperation({ summary: 'Send 6-digit SMS OTP via Termii for verification or reset' })
  async sendOtp(@Body() dto: SendOtpDto) {
    return this.authService.sendOtp(dto);
  }

  @Post('otp/verify')
  @HttpCode(HttpStatus.OK)
  @RateLimit(5, 60)
  @ApiOperation({ summary: 'Verify 6-digit SMS OTP' })
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto);
  }

  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  @RateLimit(5, 60)
  @ApiOperation({ summary: 'Reset password using OTP code' })
  async resetPassword(@Body() dto: ResetPasswordDto, @Request() req: any) {
    return this.authService.resetPassword(dto, {
      ipAddress: req.ip,
      userAgent: req.headers['user-agent'],
    });
  }

  @Delete('account')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Deactivate and anonymize user account for store compliance' })
  async deleteAccount(@Request() req: any) {
    return this.authService.deleteAccount(req.user.id, {
      ipAddress: req.ip,
      userAgent: req.headers['user-agent'],
    });
  }
}
