import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class AiParseOrderDto {
  @ApiProperty({
    example:
      'Abeg send 2 bone straight wigs to Chioma Adeyemi at 42 Allen Avenue Ikeja opposite Alade Market, 08023349912, collect 28.5k COD fragile',
  })
  @IsString()
  @IsNotEmpty()
  rawText: string;

  @ApiProperty({ example: '14 Admiralty Way, Lekki Phase 1', required: false })
  @IsOptional()
  @IsString()
  pickupLocation?: string;
}

