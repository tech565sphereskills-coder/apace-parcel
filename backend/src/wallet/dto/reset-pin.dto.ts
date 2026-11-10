import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Length, Matches } from 'class-validator';

export class ResetPinDto {
  @ApiProperty({ example: '482910', description: '6-digit SMS OTP code' })
  @IsString()
  @Length(6, 6)
  @IsNotEmpty()
  otpCode: string;

  @ApiProperty({ example: '4829', description: 'New 4-digit transaction PIN' })
  @IsString()
  @Length(4, 4)
  @Matches(/^[0-9]{4}$/, { message: 'PIN must consist of exactly 4 numeric digits' })
  newPin: string;
}

