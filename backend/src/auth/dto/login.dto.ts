import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: '+2348145550192 or michael.ogundimu@apace.ng' })
  @IsString()
  @IsNotEmpty()
  identifier: string;

  @ApiProperty({ example: 'secret1234' })
  @IsString()
  @IsNotEmpty()
  password: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  deviceId?: string;
}
