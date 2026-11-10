import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsNumber, IsString } from 'class-validator';

export class MoniepointWebhookDto {
  @ApiProperty({ example: '8145550192' })
  @IsString()
  @IsNotEmpty()
  accountNumber: string;

  @ApiProperty({ example: 20000 })
  @IsNumber()
  amount: number;

  @ApiProperty({ example: 'MNP_TXN_99210293' })
  @IsString()
  @IsNotEmpty()
  transactionReference: string;

  @ApiProperty({ example: 'Adeyemi Michael' })
  @IsString()
  @IsNotEmpty()
  senderName: string;
}

