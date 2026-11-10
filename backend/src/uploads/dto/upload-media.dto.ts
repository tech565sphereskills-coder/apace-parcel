import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class UploadMediaDto {
  @ApiProperty({ enum: ['pod', 'signature', 'kyc', 'license'], example: 'pod' })
  @IsIn(['pod', 'signature', 'kyc', 'license'])
  folder: 'pod' | 'signature' | 'kyc' | 'license';

  @ApiProperty({ example: 'image/jpeg' })
  @IsString()
  @IsNotEmpty()
  mimeType: string;

  @ApiProperty({ description: 'Base64 encoded image data' })
  @IsString()
  @IsNotEmpty()
  base64Data: string;

  @ApiProperty({ required: false, example: 'parcel-pod.jpg' })
  @IsString()
  @IsOptional()
  filename?: string;
}

