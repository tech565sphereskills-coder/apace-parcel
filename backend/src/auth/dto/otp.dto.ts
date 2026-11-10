import { ApiProperty } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsString, Length, MinLength } from 'class-validator';
import { OtpPurpose } from '@prisma/client';

export class SendOtpDto {
  @ApiProperty({ example: '+2348145550192' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiProperty({ example: 'VERIFY_PHONE', enum: OtpPurpose })
  @IsEnum(OtpPurpose)
  purpose: OtpPurpose;
}

export class VerifyOtpDto {
  @ApiProperty({ example: '+2348145550192' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiProperty({ example: 'VERIFY_PHONE', enum: OtpPurpose })
  @IsEnum(OtpPurpose)
  purpose: OtpPurpose;

  @ApiProperty({ example: '482910' })
  @IsString()
  @Length(6, 6)
  code: string;
}

export class ResetPasswordDto {
  @ApiProperty({ example: '+2348145550192' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiProperty({ example: '482910' })
  @IsString()
  @Length(6, 6)
  code: string;

  @ApiProperty({ example: 'NewSecret123!', minLength: 6 })
  @IsString()
  @MinLength(6)
  newPassword: string;
}

export class RefreshTokenDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

