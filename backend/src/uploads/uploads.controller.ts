import { Body, Controller, Post, Request, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UploadMediaDto } from './dto/upload-media.dto';
import { UploadsService } from './uploads.service';

@ApiTags('Media Uploads')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('uploads')
export class UploadsController {
  constructor(private readonly uploadsService: UploadsService) {}

  @Post('media')
  @ApiOperation({ summary: 'Upload Proof of Delivery photo, recipient signature, KYC selfie, or rider license' })
  async uploadMedia(@Request() req: any, @Body() dto: UploadMediaDto) {
    const proto = req.headers['x-forwarded-proto'] || req.protocol || 'http';
    const host = req.headers['host'];
    const origin = host ? `${proto}://${host}` : undefined;
    return this.uploadsService.saveBase64Media(req.user.id, dto, origin);
  }
}

