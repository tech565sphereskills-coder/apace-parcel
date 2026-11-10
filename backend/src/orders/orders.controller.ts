import { Body, Controller, Get, Param, Post, Query, Request, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { OrdersService } from './orders.service';
import { AiDispatchService } from './ai-dispatch.service';
import { AiParseOrderDto } from './dto/ai-parse-order.dto';
import { EstimateFareDto } from './dto/estimate-fare.dto';
import { CreateOrderDto, OptimizeCorridorDto } from './dto/create-order.dto';
import { TipRiderDto } from './dto/tip-rider.dto';
import {
  OpenDisputeDto,
  ReleaseEscrowDto,
  SendChatDto,
  SubmitPodDto,
} from './dto/order-actions.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RateLimit } from '../common/decorators/rate-limit.decorator';
import { RateLimitGuard } from '../common/guards/rate-limit.guard';

@ApiTags('Dispatches & Orders')
@UseGuards(RateLimitGuard)
@Controller('orders')
export class OrdersController {
  constructor(
    private readonly ordersService: OrdersService,
    private readonly aiDispatchService: AiDispatchService,
  ) {}

  @Post('ai-parse')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @RateLimit(20, 60)
  @ApiOperation({ summary: 'AI Magic Paste: parse messy WhatsApp/Instagram DM into structured dispatch order & Escrow COD' })
  async aiParseOrder(@Request() req: any, @Body() dto: AiParseOrderDto) {
    return this.aiDispatchService.parseOrderFromText(req.user.id, dto.rawText, dto.pickupLocation);
  }

  @Post('estimate')
  @ApiOperation({ summary: 'Instant Fare Calculator across Bike, Car, Van, and Interstate' })
  @ApiResponse({ status: 200, description: 'Comparison of all 4 fleet types with distance & ETA' })
  async estimateFare(@Body() dto: EstimateFareDto) {
    return this.ordersService.estimateFare(dto);
  }

  @Post('optimize-corridor')
  @ApiOperation({ summary: 'Corridor Route Optimizer: sort multi-stop drop-offs along shortest route & generate sub-waybill estimates' })
  async optimizeCorridor(@Body() dto: OptimizeCorridorDto) {
    return this.ordersService.optimizeCorridor(dto);
  }

  @Get('disputes/mine')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'List disputes opened by current user' })
  async getMyDisputes(@Request() req: any) {
    return this.ordersService.getMyDisputes(req.user.id);
  }

  @Post()
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @RateLimit(15, 60)
  @ApiOperation({ summary: 'Create a new dispatch shipment with wallet payment, multi-stop, and escrow options' })
  async createOrder(@Request() req: any, @Body() dto: CreateOrderDto) {
    return this.ordersService.createOrder(req.user.id, dto);
  }

  @Get()
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'List customer or rider dispatch orders with optional All/Active/Delivered filter' })
  async getOrders(@Request() req: any, @Query('filter') filter?: string) {
    return this.ordersService.getOrders(req.user.id, filter);
  }

  @Get(':id')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Get single order details by ID, AP-XXXX code, or Waybill number' })
  async getOrderById(@Request() req: any, @Param('id') id: string) {
    return this.ordersService.getOrderById(id, req.user.id, req.user.role);
  }

  @Post(':id/cancel')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Cancel an uncollected dispatch order and refund wallet' })
  async cancelOrder(@Request() req: any, @Param('id') id: string) {
    return this.ordersService.cancelOrder(req.user.id, req.user.role, id);
  }

  @Post(':id/tip')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Tip the dispatch rider from wallet balance' })
  async tipRider(@Request() req: any, @Param('id') id: string, @Body() dto: TipRiderDto) {
    return this.ordersService.tipRider(req.user.id, id, dto);
  }

  @Post(':id/escrow/release')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Verify buyer code and release held Escrow funds to merchant wallet' })
  async releaseEscrow(
    @Request() req: any,
    @Param('id') id: string,
    @Body() dto: ReleaseEscrowDto,
  ) {
    return this.ordersService.releaseEscrow(req.user.id, req.user.role, id, dto?.releaseCode);
  }

  @Get(':id/cod/ussd')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Generate Moniepoint dynamic USSD code & virtual account for Cash-On-Delivery' })
  async generateCodUssd(@Request() req: any, @Param('id') id: string) {
    return this.ordersService.generateCodUssd(req.user.id, req.user.role, id);
  }

  @Post(':id/pod')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Upload Proof of Delivery (doorstep photo, signature, OTP confirmation)' })
  async submitPod(@Request() req: any, @Param('id') id: string, @Body() dto: SubmitPodDto) {
    return this.ordersService.submitPod(req.user.id, req.user.role, id, dto);
  }

  @Get(':id/chat')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Get persisted rider-customer chat history for an order' })
  async getChat(@Request() req: any, @Param('id') id: string) {
    return this.ordersService.getChatMessages(req.user.id, req.user.role, id);
  }

  @Post(':id/chat')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Send persisted in-app chat message on an order' })
  async sendChat(@Request() req: any, @Param('id') id: string, @Body() dto: SendChatDto) {
    return this.ordersService.sendChatMessage(req.user.id, req.user.role, id, dto);
  }

  @Post(':id/dispute')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Open a delivery or escrow dispute with optional photo evidence' })
  async openDispute(@Request() req: any, @Param('id') id: string, @Body() dto: OpenDisputeDto) {
    return this.ordersService.openDispute(req.user.id, req.user.role, id, dto);
  }
}
