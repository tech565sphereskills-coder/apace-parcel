import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
  WsException,
} from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { TrackingService } from './tracking.service';
import { Role } from '@prisma/client';

@WebSocketGateway({
  cors: {
    origin: process.env.CORS_ORIGINS
      ? process.env.CORS_ORIGINS.split(',')
      : ['http://localhost:8085', 'http://localhost:3000'],
    credentials: true,
  },
})
export class TrackingGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  constructor(
    private readonly trackingService: TrackingService,
    private readonly jwtService: JwtService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const rawAuth =
        (client.handshake.auth?.token as string | undefined) ||
        (client.handshake.headers?.authorization as string | undefined);
      if (!rawAuth) {
        client.disconnect(true);
        return;
      }
      const token = rawAuth.replace(/^Bearer\s+/i, '').trim();
      const payload = await this.jwtService.verifyAsync(token, {
        secret: process.env.JWT_SECRET || 'apace_super_secret_jwt_key_ng_2026',
      });
      client.data.user = {
        id: payload.sub,
        phone: payload.phone,
        role: payload.role as Role,
      };
      client.join(`user_${payload.sub}`);
      client.join(`rider_${payload.sub}`);
      return { status: 'connected', clientId: client.id };
    } catch {
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    return { status: 'disconnected', clientId: client.id };
  }

  @SubscribeMessage('joinOrderTracking')
  async handleJoinOrderTracking(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { orderId: string },
  ) {
    const user = client.data?.user;
    if (!user) {
      throw new WsException('Unauthorized WebSocket session');
    }
    const order = await this.trackingService.verifyOrderParticipant(
      data.orderId,
      user.id,
      user.role,
    );
    const room = `order_${order.id}`;
    const numberRoom = `order_${order.orderNumber}`;
    client.join(room);
    client.join(numberRoom);
    return { event: 'joined', room };
  }

  @SubscribeMessage('updateRiderLocation')
  async handleUpdateRiderLocation(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
      orderId: string;
      latitude: number;
      longitude: number;
      heading?: number;
      speed?: number;
    },
  ) {
    const user = client.data?.user;
    if (!user) {
      throw new WsException('Unauthorized WebSocket session');
    }

    const order = await this.trackingService.verifyOrderParticipant(
      data.orderId,
      user.id,
      user.role,
    );
    if (user.role !== Role.ADMIN && order.riderId !== user.id) {
      throw new WsException('Only the assigned dispatch rider can stream live telemetry');
    }
    const telemetry = await this.trackingService.processRiderTelemetry({
      riderId: user.id,
      orderId: order.id,
      latitude: data.latitude,
      longitude: data.longitude,
      reportedSpeedKmh: data.speed,
    });

    if (telemetry.rejected) {
      client.emit('geofenceRejected', telemetry);
      return {
        status: 'rejected',
        reason: telemetry.reason,
        speedKmh: telemetry.speedKmh,
      };
    }

    const payload = {
      orderId: order.id,
      orderNumber: order.orderNumber,
      latitude: data.latitude,
      longitude: data.longitude,
      heading: data.heading || 0,
      speed: telemetry.speedKmh,
      timestamp: new Date().toISOString(),
    };

    this.server.to(`order_${order.id}`).emit('riderLocationUpdated', payload);
    this.server.to(`order_${order.orderNumber}`).emit('riderLocationUpdated', payload);

    if (telemetry.geofenceEvent) {
      this.server.to(`order_${order.id}`).emit('geofenceTriggered', telemetry.geofenceEvent);
      this.server.to(`order_${order.orderNumber}`).emit('geofenceTriggered', telemetry.geofenceEvent);
      this.server.to(`rider_${user.id}`).emit('geofenceTriggered', telemetry.geofenceEvent);
    }

    return {
      status: 'broadcasted',
      speedKmh: telemetry.speedKmh,
      geofenceEvent: telemetry.geofenceEvent || null,
    };
  }

  @SubscribeMessage('verifyHandoverOtp')
  async handleVerifyHandoverOtp(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { orderId: string; otp: string },
  ) {
    const user = client.data?.user;
    if (!user) {
      throw new WsException('Unauthorized WebSocket session');
    }

    const result = await this.trackingService.verifyHandoverOtp(
      data.orderId,
      data.otp,
      user.id,
      user.role,
    );

    if (result.success && result.order) {
      const event = {
        orderId: result.order.id,
        orderNumber: result.order.orderNumber,
        status: 'DELIVERED',
        deliveredAt: new Date().toISOString(),
      };
      this.server.to(`order_${result.order.id}`).emit('orderStatusUpdated', event);
      this.server.to(`order_${result.order.orderNumber}`).emit('orderStatusUpdated', event);
    }

    return result;
  }

  @SubscribeMessage('sendOrderChatMessage')
  async handleOrderChatMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { orderId: string; message: string },
  ) {
    const user = client.data?.user;
    if (!user || !data.message?.trim()) {
      throw new WsException('Invalid chat payload');
    }

    const saved = await this.trackingService.persistChatMessage(
      data.orderId,
      user.id,
      user.role,
      data.message,
    );

    this.server.to(`order_${saved.orderId}`).emit('orderChatMessage', saved);
    return saved;
  }

  @SubscribeMessage('riderJoinRadar')
  handleRiderJoinRadar(@ConnectedSocket() client: Socket) {
    const user = client.data?.user;
    if (!user) {
      throw new WsException('Unauthorized WebSocket session');
    }
    const riderRoom = `rider_${user.id}`;
    client.join(riderRoom);
    client.join('online_riders');
    return { status: 'radar_active', room: riderRoom };
  }
}
