import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateAddressDto } from './dto/create-address.dto';

@Injectable()
export class AddressesService {
  constructor(private prisma: PrismaService) {}

  async list(userId: string) {
    return this.prisma.savedAddress.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(userId: string, dto: CreateAddressDto) {
    return this.prisma.savedAddress.create({
      data: {
        userId,
        title: dto.title,
        street: dto.street,
        landmark: dto.landmark,
        contactName: dto.contactName,
        contactPhone: dto.contactPhone,
        tag: dto.tag || 'home',
      },
    });
  }

  async remove(userId: string, id: string) {
    const addr = await this.prisma.savedAddress.findUnique({ where: { id } });
    if (!addr) {
      throw new NotFoundException('Saved address not found');
    }
    if (addr.userId !== userId) {
      throw new ForbiddenException('Cannot remove another user saved address');
    }
    await this.prisma.savedAddress.delete({ where: { id } });
    return { success: true, message: 'Address removed' };
  }
}

