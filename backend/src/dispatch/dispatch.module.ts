import { Global, Module } from '@nestjs/common';
import { DispatchEngineService } from './dispatch-engine.service';
import { TrackingModule } from '../tracking/tracking.module';

@Global()
@Module({
  imports: [TrackingModule],
  providers: [DispatchEngineService],
  exports: [DispatchEngineService],
})
export class DispatchModule {}

