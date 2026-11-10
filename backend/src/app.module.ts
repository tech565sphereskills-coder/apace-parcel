import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { AuditModule } from './audit/audit.module';
import { IntegrationsModule } from './integrations/integrations.module';
import { AuthModule } from './auth/auth.module';
import { KycModule } from './kyc/kyc.module';
import { WalletModule } from './wallet/wallet.module';
import { OrdersModule } from './orders/orders.module';
import { TrackingModule } from './tracking/tracking.module';
import { DispatchModule } from './dispatch/dispatch.module';
import { RiderModule } from './rider/rider.module';
import { AddressesModule } from './addresses/addresses.module';
import { NotificationsModule } from './notifications/notifications.module';
import { UploadsModule } from './uploads/uploads.module';
import { AdminModule } from './admin/admin.module';
import { HealthModule } from './health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuditModule,
    IntegrationsModule,
    AuthModule,
    KycModule,
    WalletModule,
    OrdersModule,
    TrackingModule,
    DispatchModule,
    RiderModule,
    AddressesModule,
    NotificationsModule,
    UploadsModule,
    AdminModule,
    HealthModule,
  ],
})
export class AppModule {}
