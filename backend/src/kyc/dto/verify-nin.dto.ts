import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsNotEmpty, IsString, Length } from 'class-validator';

export class VerifyNinDto {
  @ApiProperty({ example: '29481029384', description: '11-digit Nigerian NIN or BVN' })
  @IsString()
  @IsNotEmpty()
  @Length(11, 14)
  identityNumber: string;

  @ApiProperty({ example: 'NIN', enum: ['NIN', 'BVN'] })
  @IsIn(['NIN', 'BVN'])
  method: 'NIN' | 'BVN';
}

