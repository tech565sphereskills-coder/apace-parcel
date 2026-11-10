import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class SubmitPodDto {
  @ApiProperty({ example: 'data:image/png;base64,...', required: false })
  @IsOptional()
  @IsString()
  recipientSignature?: string;

  @ApiProperty({ example: 'https://cdn.apace.ng/pod/AP-4821.jpg', required: false })
  @IsOptional()
  @IsString()
  proofPhotoUrl?: string;

  @ApiProperty({ example: '4829', required: false })
  @IsOptional()
  @IsString()
  handoverOtp?: string;
}

export class SendChatDto {
  @ApiProperty({ example: 'I am at the estate gate now.' })
  @IsString()
  @IsNotEmpty()
  message: string;
}

export class OpenDisputeDto {
  @ApiProperty({ example: 'Damaged Item / Wrong Delivery' })
  @IsString()
  @IsNotEmpty()
  reason: string;

  @ApiProperty({ example: 'Parcel arrived with broken seal.' })
  @IsString()
  @IsNotEmpty()
  description: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  evidenceUrl?: string;
}

export class ReleaseEscrowDto {
  @ApiProperty({ example: '7192', required: false })
  @IsOptional()
  @IsString()
  releaseCode?: string;
}

