import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsEmail, IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class OAuthLoginDto {
  @ApiProperty({ enum: ['google', 'apple'], example: 'google' })
  @IsIn(['google', 'apple'])
  provider: 'google' | 'apple';

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  idToken?: string;

  @ApiProperty({ example: 'chioma.okafor@gmail.com' })
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @ApiProperty({ example: 'Chioma Okafor' })
  @IsString()
  @IsNotEmpty()
  fullName: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  deviceId?: string;
}

export class UpdatePreferencesDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  @IsOptional()
  notifyWhatsapp?: boolean;

  @ApiProperty({ example: true })
  @IsBoolean()
  @IsOptional()
  notifySms?: boolean;

  @ApiProperty({ example: true })
  @IsBoolean()
  @IsOptional()
  notifyPush?: boolean;
}

