import { Body, Controller, Get, Param, Patch, Request, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsIn, IsNotEmpty, IsNumber, IsString } from 'class-validator';
import { Role } from '@prisma/client';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';

class ResolveDisputeDto {
  @ApiProperty({ enum: ['RESOLVED_REFUND', 'RESOLVED_RELEASE'] })
  @IsIn(['RESOLVED_REFUND', 'RESOLVED_RELEASE'])
  resolution: 'RESOLVED_REFUND' | 'RESOLVED_RELEASE';

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  notes: string;
}

class UpdateKycTierDto {
  @ApiProperty({ example: 3 })
  @IsNumber()
  tier: number;
}

@ApiTags('Admin Operations')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('overview')
  @ApiOperation({ summary: 'Platform operational and financial overview metrics' })
  async overview() {
    return this.adminService.getOverview();
  }

  @Get('disputes')
  @ApiOperation({ summary: 'List all escrow and delivery disputes' })
  async listDisputes() {
    return this.adminService.listDisputes();
  }

  @Patch('disputes/:id/resolve')
  @ApiOperation({ summary: 'Resolve an escrow/delivery dispute with refund or release' })
  async resolveDispute(
    @Request() req: any,
    @Param('id') id: string,
    @Body() dto: ResolveDisputeDto,
  ) {
    return this.adminService.resolveDispute(req.user.id, id, dto.resolution, dto.notes);
  }

  @Patch('kyc/:userId')
  @ApiOperation({ summary: 'Manually approve or adjust user KYC tier' })
  async updateKyc(
    @Request() req: any,
    @Param('userId') userId: string,
    @Body() dto: UpdateKycTierDto,
  ) {
    return this.adminService.updateUserKycTier(req.user.id, userId, dto.tier);
  }

  @Get('audit-logs')
  @ApiOperation({ summary: 'View recent security and financial audit trail logs' })
  async auditLogs() {
    return this.adminService.getAuditLogs();
  }

  @Get('riders')
  @ApiOperation({ summary: 'List onboarded dispatch riders and compliance status' })
  async listRiders() {
    return this.adminService.listRiders();
  }

  @Patch('riders/:userId/approve')
  @ApiOperation({ summary: 'Approve or reject a rider onboarding submission' })
  async approveRider(
    @Request() req: any,
    @Param('userId') userId: string,
    @Body('status') status: 'APPROVED' | 'REJECTED',
  ) {
    return this.adminService.approveRider(
      req.user.id,
      userId,
      status === 'REJECTED' ? 'REJECTED' : 'APPROVED',
    );
  }
}

