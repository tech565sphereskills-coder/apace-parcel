import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsIn, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';

export class RegisterDto {
  @ApiProperty({ example: 'Michael Ogundimu' })
  @IsString()
  @IsNotEmpty()
  fullName: string;

  @ApiProperty({ example: '+2348145550192' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiProperty({ example: 'michael.ogundimu@apace.ng', required: false })
  @IsEmail()
  @IsOptional()
  email?: string;

  @ApiProperty({ example: 'secret1234', minLength: 6 })
  @IsString()
  @MinLength(6)
  password: string;

  @ApiProperty({ example: '29481029384', required: false })
  @IsString()
  @IsOptional()
  ninNumber?: string;

  @ApiProperty({ example: 'CUSTOMER', enum: ['CUSTOMER', 'RIDER'], required: false })
  @IsOptional()
  @IsIn(['CUSTOMER', 'RIDER'])
  role?: 'CUSTOMER' | 'RIDER';

  @ApiProperty({ example: 'Motorcycle', required: false })
  @IsOptional()
  @IsString()
  vehicleType?: string;

  @ApiProperty({ example: 'LAG-492-QA', required: false })
  @IsOptional()
  @IsString()
  plateNumber?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  deviceId?: string;
}
