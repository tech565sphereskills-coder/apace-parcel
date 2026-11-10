import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Length, Matches } from 'class-validator';

export class ResolveAccountDto {
  @ApiProperty({ example: '0123456789' })
  @IsString()
  @Length(10, 10)
  @Matches(/^\d{10}$/)
  accountNumber: string;

  @ApiProperty({ example: '044', description: 'CBN bank code e.g. 044 for Access, 058 for GTBank' })
  @IsString()
  @IsNotEmpty()
  bankCode: string;
}

