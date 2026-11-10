import { Module } from '@nestjs/common';
import { OrdersService } from './orders.service';
import { OrdersController } from './orders.controller';
import { AiDispatchService } from './ai-dispatch.service';

@Module({
  controllers: [OrdersController],
  providers: [OrdersService, AiDispatchService],
  exports: [OrdersService, AiDispatchService],
})
export class OrdersModule {}
