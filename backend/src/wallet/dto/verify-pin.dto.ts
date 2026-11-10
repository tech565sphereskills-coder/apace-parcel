import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Length, Matches } from 'class-validator';

export class VerifyPinDto {
  @ApiProperty({ example: '4829', description: '4-digit transaction PIN to verify' })
  @IsNotEmpty()
  @IsString()
  @Length(4, 4)
  @Matches(/^[0-9]{4}$/, { message: 'PIN must consist of exactly 4 numeric digits' })
  pin: string;
}

