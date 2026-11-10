import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import { ServiceType } from '@prisma/client';

export class CreateOrderStopDto {
  @ApiProperty({ example: '42 Allen Avenue, Ikeja, Lagos' })
  @IsString()
  @IsNotEmpty()
  address: string;

  @ApiProperty({ example: 'Opposite Alade Market', required: false })
  @IsString()
  @IsOptional()
  landmark?: string;

  @ApiProperty({ example: 'Chioma Adeyemi' })
  @IsString()
  @IsNotEmpty()
  contactName: string;

  @ApiProperty({ example: '+2348023349912' })
  @IsString()
  @IsNotEmpty()
  contactPhone: string;

  @ApiProperty({ example: 6.6018, required: false })
  @IsNumber()
  @IsOptional()
  lat?: number;

  @ApiProperty({ example: 3.3515, required: false })
  @IsNumber()
  @IsOptional()
  lng?: number;

  @ApiProperty({ example: 1, required: false })
  @IsNumber()
  @IsOptional()
  sequence?: number;

  @ApiProperty({ example: 4.2, required: false })
  @IsNumber()
  @IsOptional()
  legKm?: number;
}

export class OptimizeCorridorDto {
  @ApiProperty({ example: '14 Admiralty Way, Lekki Phase 1' })
  @IsString()
  @IsNotEmpty()
  pickupAddress: string;

  @ApiProperty({ example: 6.4474, required: false })
  @IsNumber()
  @IsOptional()
  pickupLat?: number;

  @ApiProperty({ example: 3.4723, required: false })
  @IsNumber()
  @IsOptional()
  pickupLng?: number;

  @ApiProperty({ type: [CreateOrderStopDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateOrderStopDto)
  stops: CreateOrderStopDto[];
}

export class CreateOrderDto {
  @ApiProperty({ example: 'BIKE', enum: ServiceType })
  @IsEnum(ServiceType)
  serviceType: ServiceType;

  @ApiProperty({ example: '14 Admiralty Way, Lekki Phase 1' })
  @IsString()
  @IsNotEmpty()
  pickupAddress: string;

  @ApiProperty({ example: 'Beside Ebeano Supermarket', required: false })
  @IsString()
  @IsOptional()
  pickupLandmark?: string;

  @ApiProperty({ example: 'Michael Ogundimu' })
  @IsString()
  @IsNotEmpty()
  pickupContactName: string;

  @ApiProperty({ example: '+2348145550192' })
  @IsString()
  @IsNotEmpty()
  pickupContactPhone: string;

  @ApiProperty({ example: 6.4474, required: false })
  @IsNumber()
  @IsOptional()
  pickupLat?: number;

  @ApiProperty({ example: 3.4723, required: false })
  @IsNumber()
  @IsOptional()
  pickupLng?: number;

  @ApiProperty({ example: '42 Allen Avenue, Ikeja, Lagos' })
  @IsString()
  @IsNotEmpty()
  dropoffAddress: string;

  @ApiProperty({ example: 'Opposite Alade Market', required: false })
  @IsString()
  @IsOptional()
  dropoffLandmark?: string;

  @ApiProperty({ example: 'Chioma Adeyemi' })
  @IsString()
  @IsNotEmpty()
  dropoffContactName: string;

  @ApiProperty({ example: '+2348023349912' })
  @IsString()
  @IsNotEmpty()
  dropoffContactPhone: string;

  @ApiProperty({ example: 6.6018, required: false })
  @IsNumber()
  @IsOptional()
  dropoffLat?: number;

  @ApiProperty({ example: 3.3515, required: false })
  @IsNumber()
  @IsOptional()
  dropoffLng?: number;

  @ApiProperty({ example: 14.5, required: false })
  @IsNumber()
  @IsPositive()
  @IsOptional()
  distanceKm?: number;

  @ApiProperty({ example: 'Documents / Electronics', required: false })
  @IsString()
  @IsOptional()
  packageCategory?: string;

  @ApiProperty({ example: 3850 })
  @IsNumber()
  @IsPositive()
  price: number;

  @ApiProperty({ example: 'WALLET', default: 'WALLET' })
  @IsString()
  @IsOptional()
  paymentMethod?: string;

  @ApiProperty({ example: 1, default: 1, required: false })
  @IsNumber()
  @Min(1)
  @IsOptional()
  stopsCount?: number;

  @ApiProperty({ example: true, default: false, required: false })
  @IsBoolean()
  @IsOptional()
  includeInsurance?: boolean;

  @ApiProperty({ example: 'Today, 3:00 PM - 5:00 PM', required: false })
  @IsString()
  @IsOptional()
  scheduledTime?: string;

  @ApiProperty({ example: false, default: false, required: false })
  @IsBoolean()
  @IsOptional()
  isEscrow?: boolean;

  @ApiProperty({ example: 18500, default: 0, required: false })
  @IsNumber()
  @IsOptional()
  escrowAmount?: number;

  @ApiProperty({ example: '4829', required: false, description: '4-digit transaction PIN' })
  @IsString()
  @IsOptional()
  transactionPin?: string;

  @ApiProperty({ type: [CreateOrderStopDto], required: false })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateOrderStopDto)
  @IsOptional()
  stops?: CreateOrderStopDto[];
}
