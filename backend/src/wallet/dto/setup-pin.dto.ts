import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Length, Matches } from 'class-validator';

export class SetupPinDto {
  @ApiProperty({ example: '4829', description: '4-digit secret transaction PIN' })
  @IsNotEmpty()
  @IsString()
  @Length(4, 4)
  @Matches(/^[0-9]{4}$/, { message: 'PIN must consist of exactly 4 numeric digits' })
  pin: string;
}

