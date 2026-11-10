import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsEnum, IsIn, IsNotEmpty, IsNumber, IsOptional, IsString } from 'class-validator';
import { OrderStatus } from '@prisma/client';

export class UpdateAvailabilityDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  isOnline: boolean;

  @ApiProperty({ example: 6.4474, required: false })
  @IsOptional()
  @IsNumber()
  latitude?: number;

  @ApiProperty({ example: 3.4723, required: false })
  @IsOptional()
  @IsNumber()
  longitude?: number;
}

export class UpdateOrderStatusDto {
  @ApiProperty({ example: 'PICKED_UP', enum: OrderStatus })
  @IsEnum(OrderStatus)
  status: OrderStatus;

  @ApiProperty({ example: '4829', required: false })
  @IsOptional()
  @IsString()
  handoverOtp?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  recipientSignature?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  proofPhotoUrl?: string;
}

export class CompleteStopDto {
  @ApiProperty({ example: '4829' })
  @IsString()
  @IsNotEmpty()
  handoverOtp: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  proofPhotoUrl?: string;
}

export class RiderOnboardDto {
  @ApiProperty({ example: 'Motorcycle' })
  @IsString()
  @IsNotEmpty()
  vehicleType: string;

  @ApiProperty({ example: 'Bajaj Boxer 150cc' })
  @IsString()
  @IsOptional()
  vehicleModel?: string;

  @ApiProperty({ example: 'LA-492-IKJ' })
  @IsString()
  @IsNotEmpty()
  plateNumber: string;

  @ApiProperty({ example: 'FKJ-894321-AA' })
  @IsString()
  @IsNotEmpty()
  licenseNumber: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  licensePhotoUrl?: string;

  @ApiProperty({ example: 'Adebayo Ogunleye' })
  @IsString()
  @IsNotEmpty()
  guarantorName: string;

  @ApiProperty({ example: '+2348034451120' })
  @IsString()
  @IsNotEmpty()
  guarantorPhone: string;
}

export class ReportDelayDto {
  @ApiProperty({ enum: ['ESTATE_GATE_HOLD', 'TRAFFIC_CONGESTION', 'WEATHER_HOLD'] })
  @IsIn(['ESTATE_GATE_HOLD', 'TRAFFIC_CONGESTION', 'WEATHER_HOLD'])
  flagType: 'ESTATE_GATE_HOLD' | 'TRAFFIC_CONGESTION' | 'WEATHER_HOLD';

  @ApiProperty({ required: false, example: 'Waiting at Lekki Phase 1 gate for resident code' })
  @IsOptional()
  @IsString()
  note?: string;
}
