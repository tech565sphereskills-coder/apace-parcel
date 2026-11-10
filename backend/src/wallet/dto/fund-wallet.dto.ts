import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsNumber, IsOptional, IsPositive, IsString } from 'class-validator';

export class FundWalletDto {
  @ApiProperty({ example: 5000, description: 'Amount in Naira' })
  @IsNumber()
  @IsPositive()
  amount: number;

  @ApiProperty({ example: 'Paystack Debit Card' })
  @IsString()
  @IsNotEmpty()
  method: string;

  @ApiProperty({ example: 'PSK_REF_19283746', required: false })
  @IsOptional()
  @IsString()
  paymentReference?: string;
}
