import { Global, Module } from '@nestjs/common';
import { NigerianProvidersService } from './nigerian-providers.service';

@Global()
@Module({
  providers: [NigerianProvidersService],
  exports: [NigerianProvidersService],
})
export class IntegrationsModule {}

