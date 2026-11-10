import { Body, Controller, Delete, Get, Param, Patch, Post, Request, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';

class DeviceTokenDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  token: string;

  @ApiProperty({ example: 'android' })
  @IsString()
  @IsNotEmpty()
  platform: string;
}

@ApiTags('Push Notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Post('device-token')
  @ApiOperation({ summary: 'Register FCM device push notification token' })
  async register(@Request() req: any, @Body() dto: DeviceTokenDto) {
    return this.notificationsService.registerDeviceToken(req.user.id, dto.token, dto.platform);
  }

  @Delete('device-token')
  @ApiOperation({ summary: 'Remove push notification token on logout' })
  async unregister(@Request() req: any, @Body('token') token: string) {
    return this.notificationsService.unregisterDeviceToken(req.user.id, token || '');
  }

  @Get('history')
  @ApiOperation({ summary: 'Get push and dispatch notification history' })
  async history(@Request() req: any) {
    return this.notificationsService.getHistory(req.user.id);
  }

  @Patch(':id/read')
  @ApiOperation({ summary: 'Mark a notification as read' })
  async markRead(@Request() req: any, @Param('id') id: string) {
    return this.notificationsService.markRead(req.user.id, id);
  }
}
