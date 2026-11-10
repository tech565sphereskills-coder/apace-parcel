import { Body, Controller, Get, Param, Patch, Post, Request, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { RiderService } from './rider.service';
import {
  CompleteStopDto,
  ReportDelayDto,
  RiderOnboardDto,
  UpdateAvailabilityDto,
  UpdateOrderStatusDto,
} from './dto/rider.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '@prisma/client';

@ApiTags('Rider Dispatch Portal')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.RIDER, Role.ADMIN, Role.CUSTOMER)
@Controller('rider')
export class RiderController {
  constructor(private readonly riderService: RiderService) {}

  @Get('dashboard')
  @ApiOperation({ summary: 'Get rider profile, active dispatch, and today earnings' })
  async getDashboard(@Request() req: any) {
    return this.riderService.getDashboard(req.user.id);
  }

  @Post('onboard')
  @ApiOperation({ summary: 'Submit rider compliance documents (driver license, plate, guarantor)' })
  async onboardRider(@Request() req: any, @Body() dto: RiderOnboardDto) {
    return this.riderService.onboardRider(req.user.id, dto);
  }

  @Patch('availability')
  @ApiOperation({ summary: 'Toggle online dispatch availability and update GPS coordinates' })
  async updateAvailability(@Request() req: any, @Body() dto: UpdateAvailabilityDto) {
    return this.riderService.updateAvailability(req.user.id, dto);
  }

  @Get('available-orders')
  @ApiOperation({ summary: 'List unassigned SEARCHING dispatch requests nearby' })
  async getAvailableOrders() {
    return this.riderService.getAvailableOrders();
  }

  @Get('offers/pending')
  @ApiOperation({ summary: 'Get active 15-second dispatch auction offers targeted at this rider' })
  async getPendingOffers(@Request() req: any) {
    return this.riderService.getPendingOffers(req.user.id);
  }

  @Post('offers/:offerId/accept')
  @ApiOperation({ summary: 'Accept a live timed DispatchOffer before it expires' })
  async acceptOffer(@Request() req: any, @Param('offerId') offerId: string) {
    return this.riderService.acceptOffer(req.user.id, offerId);
  }

  @Post('offers/:offerId/decline')
  @ApiOperation({ summary: 'Decline a live DispatchOffer to immediately cascade to next rider' })
  async declineOffer(@Request() req: any, @Param('offerId') offerId: string) {
    return this.riderService.declineOffer(req.user.id, offerId);
  }

  @Post('orders/:id/accept')
  @ApiOperation({ summary: 'Atomically claim an unassigned dispatch order' })
  async acceptOrder(@Request() req: any, @Param('id') id: string) {
    return this.riderService.acceptOrder(req.user.id, id);
  }

  @Post('orders/:id/status')
  @ApiOperation({ summary: 'Transition assigned order status, record POD, and credit rider payout on delivery' })
  async updateStatus(
    @Request() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateOrderStatusDto,
  ) {
    return this.riderService.updateOrderStatus(req.user.id, id, dto);
  }

  @Post('stops/:stopId/complete')
  @ApiOperation({ summary: 'Complete an individual multi-stop sub-waybill using recipient OTP & POD photo' })
  async completeStop(
    @Request() req: any,
    @Param('stopId') stopId: string,
    @Body() dto: CompleteStopDto,
  ) {
    return this.riderService.completeOrderStop(req.user.id, stopId, dto);
  }

  @Post('orders/:id/delay-flag')
  @ApiOperation({ summary: 'Broadcast estate security gate hold, Lagos traffic, or weather delay to customer' })
  async reportDelay(
    @Request() req: any,
    @Param('id') id: string,
    @Body() dto: ReportDelayDto,
  ) {
    return this.riderService.reportDelayFlag(req.user.id, id, dto);
  }
}
