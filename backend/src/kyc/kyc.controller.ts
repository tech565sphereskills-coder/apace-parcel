import { Body, Controller, Get, Post, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiResponse } from '@nestjs/swagger';
import { KycService } from './kyc.service';
import { VerifyNinDto } from './dto/verify-nin.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';

@ApiTags('KYC & Compliance')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('kyc')
export class KycController {
  constructor(private readonly kycService: KycService) {}

  @Get('status')
  @ApiOperation({ summary: 'Get current customer KYC tier, verification status, and daily limits' })
  async getStatus(@Request() req: any) {
    return this.kycService.getKycStatus(req.user.id);
  }

  @Post('verify-identity')
  @ApiOperation({ summary: 'Verify 11-digit NIN or BVN for instant Tier 2 upgrade' })
  @ApiResponse({ status: 200, description: 'NIMC identity matched and Tier 2 approved' })
  async verifyIdentity(@Request() req: any, @Body() dto: VerifyNinDto) {
    return this.kycService.verifyIdentity(req.user.id, dto);
  }

  @Post('verify-liveness')
  @ApiOperation({ summary: 'Complete AI Facial Liveness scan to unlock Tier 3' })
  @ApiResponse({ status: 200, description: 'Biometric liveness confirmed and Tier 3 activated' })
  async verifyLiveness(@Request() req: any) {
    return this.kycService.verifyLiveness(req.user.id);
  }
}

