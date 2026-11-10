import { Body, Controller, Delete, Get, Param, Post, Request, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AddressesService } from './addresses.service';
import { CreateAddressDto } from './dto/create-address.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';

@ApiTags('Saved Addresses')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('addresses')
export class AddressesController {
  constructor(private readonly addressesService: AddressesService) {}

  @Get()
  @ApiOperation({ summary: 'List user saved Nigerian delivery addresses' })
  async list(@Request() req: any) {
    return this.addressesService.list(req.user.id);
  }

  @Post()
  @ApiOperation({ summary: 'Save a frequent pickup or drop-off landmark address' })
  async create(@Request() req: any, @Body() dto: CreateAddressDto) {
    return this.addressesService.create(req.user.id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Remove a saved address' })
  async remove(@Request() req: any, @Param('id') id: string) {
    return this.addressesService.remove(req.user.id, id);
  }
}

