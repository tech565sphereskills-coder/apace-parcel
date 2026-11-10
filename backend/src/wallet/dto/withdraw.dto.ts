import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsNumber, IsOptional, IsPositive, IsString, Length } from 'class-validator';

export class WithdrawDto {
  @ApiProperty({ example: 5000, description: 'Amount in Naira' })
  @IsNumber()
  @IsPositive()
  amount: number;

  @ApiProperty({ example: 'Access Bank' })
  @IsString()
  @IsNotEmpty()
  bankName: string;

  @ApiProperty({ example: '0123456789', description: '10-digit NUBAN account number' })
  @IsString()
  @Length(10, 10)
  accountNumber: string;

  @ApiProperty({ example: '4829', required: false, description: '4-digit transaction PIN' })
  @IsOptional()
  @IsString()
  pin?: string;
}

