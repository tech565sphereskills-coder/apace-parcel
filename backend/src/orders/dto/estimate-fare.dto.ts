import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsNotEmpty, IsNumber, IsOptional, IsPositive, IsString, Min } from 'class-validator';

export class EstimateFareDto {
  @ApiProperty({ example: 'Lekki Phase 1, Lagos' })
  @IsString()
  @IsNotEmpty()
  pickupLocation: string;

  @ApiProperty({ example: 'Allen Avenue, Ikeja' })
  @IsString()
  @IsNotEmpty()
  dropoffLocation: string;

  @ApiProperty({ example: 14.5, required: false })
  @IsNumber()
  @IsPositive()
  @IsOptional()
  distanceKm?: number;

  @ApiProperty({ example: 6.4474, required: false })
  @IsNumber()
  @IsOptional()
  pickupLat?: number;

  @ApiProperty({ example: 3.4723, required: false })
  @IsNumber()
  @IsOptional()
  pickupLng?: number;

  @ApiProperty({ example: 6.6018, required: false })
  @IsNumber()
  @IsOptional()
  dropoffLat?: number;

  @ApiProperty({ example: 3.3515, required: false })
  @IsNumber()
  @IsOptional()
  dropoffLng?: number;

  @ApiProperty({ example: 1, required: false })
  @IsNumber()
  @Min(1)
  @IsOptional()
  stopsCount?: number;

  @ApiProperty({ example: true, required: false })
  @IsBoolean()
  @IsOptional()
  includeInsurance?: boolean;
}
