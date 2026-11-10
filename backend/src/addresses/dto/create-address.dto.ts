import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateAddressDto {
  @ApiProperty({ example: 'Home (Lekki Phase 1)' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({ example: '14 Admiralty Way, Lekki Phase 1' })
  @IsString()
  @IsNotEmpty()
  street: string;

  @ApiProperty({ example: 'Beside Ebeano Supermarket', required: false })
  @IsOptional()
  @IsString()
  landmark?: string;

  @ApiProperty({ example: 'Michael Ogundimu' })
  @IsString()
  @IsNotEmpty()
  contactName: string;

  @ApiProperty({ example: '+234 814 555 0192' })
  @IsString()
  @IsNotEmpty()
  contactPhone: string;

  @ApiProperty({ example: 'home', required: false })
  @IsOptional()
  @IsString()
  tag?: string;
}

