import { ApiProperty } from '@nestjs/swagger';
import { IsNumber, IsPositive } from 'class-validator';

export class TipRiderDto {
  @ApiProperty({ example: 500, description: 'Tip amount in Naira (e.g. 200, 500, 1000, 2000)' })
  @IsNumber()
  @IsPositive()
  amount: number;
}

