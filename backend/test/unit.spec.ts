import { test } from 'node:test';
import * as assert from 'node:assert/strict';
import * as fs from 'fs';
import * as path from 'path';
import { AiDispatchService } from '../src/orders/ai-dispatch.service';
import { OrdersService } from '../src/orders/orders.service';
import { TrackingService } from '../src/tracking/tracking.service';
import { UploadsService } from '../src/uploads/uploads.service';
import { RiderService } from '../src/rider/rider.service';
import { OrderStatus, StopStatus } from '@prisma/client';

test('AI Magic Paste extracts Nigerian phone, address, landmark, category & Escrow COD', async () => {
  const mockPrisma = { savedAddress: { findFirst: async () => null } } as any;
  const service = new AiDispatchService(mockPrisma);
  const res = await service.parseOrderFromText(
    'user-1',
    'Abeg send 2 bone straight wigs to Chioma Adeyemi at 42 Allen Avenue Ikeja opposite Alade Market, 08023349912, collect 28.5k COD fragile',
  );

  assert.equal(res.recipientName, 'Chioma Adeyemi');
  assert.equal(res.recipientPhone, '+234 802 334 9912');
  assert.equal(res.dropoffAddress, '42 Allen Avenue Ikeja');
  assert.equal(res.dropoffLandmark, 'Opposite Alade Market');
  assert.equal(res.packageCategory, 'Fashion & Retail');
  assert.equal(res.isEscrow, true);
  assert.equal(res.escrowAmount, 28500);
});

test('Corridor Route Optimizer reorders stops along nearest corridor from Lekki pickup', async () => {
  const ordersService = new OrdersService({} as any, {} as any, {} as any);
  const plan = await ordersService.optimizeCorridor({
    pickupAddress: '14 Admiralty Way, Lekki Phase 1',
    stops: [
      {
        address: '42 Allen Avenue, Ikeja',
        contactName: 'Chioma',
        contactPhone: '+2348023349912',
      },
      {
        address: 'Plot 12 Adeola Odeku, Victoria Island',
        contactName: 'Tunde',
        contactPhone: '+2348031122334',
      },
      {
        address: '8 Herbert Macaulay Way, Yaba',
        contactName: 'Kemi',
        contactPhone: '+2348095566778',
      },
    ],
  });

  assert.equal(plan.optimizedStops.length, 3);
  assert.match(plan.optimizedStops[0].address, /Victoria Island/i);
  assert.ok(plan.optimizedDistanceKm < plan.rawDistanceKm);
  assert.ok(plan.distanceSavedKm > 0);
  assert.equal(plan.batchDiscountPercent, 15);
});

test('TrackingService detects 150m dropoff geofence and rejects >140 km/h GPS spoofing', async () => {
  let updatedSpoofFlags = 0;
  let updatedOrderGeofence: string | null = null;
  let updatedStopStatus: StopStatus | null = null;

  const mockPrisma = {
    riderProfile: {
      findUnique: async () => ({
        userId: 'rider-1',
        currentLat: 6.6018,
        currentLng: 3.3515,
        lastLocationAt: new Date(Date.now() - 8000),
      }),
      update: async (args: any) => {
        if (args.data?.spoofFlags?.increment) {
          updatedSpoofFlags += args.data.spoofFlags.increment;
        }
        return {};
      },
    },
    deliveryOrder: {
      findFirst: async () => ({
        id: 'ord-1',
        orderNumber: 'AP-9901',
        senderId: 'cust-1',
        riderId: 'rider-1',
        status: OrderStatus.IN_TRANSIT,
        geofenceStatus: null,
        isEscrow: true,
        escrowAmount: 28500,
        escrowReleaseCode: '8821',
        dropoffLat: 6.6018,
        dropoffLng: 3.3515,
        stops: [
          {
            id: 'stop-1',
            sequence: 1,
            subWaybillCode: 'WB-1-S1',
            contactName: 'Chioma',
            lat: 6.6018,
            lng: 3.3515,
            status: StopStatus.PENDING,
          },
        ],
      }),
      update: async (args: any) => {
        updatedOrderGeofence = args.data.geofenceStatus;
        return {};
      },
    },
    orderStop: {
      update: async (args: any) => {
        updatedStopStatus = args.data.status;
        return {};
      },
    },
  } as any;

  const mockAudit = { log: async () => {} } as any;
  const mockNotify = { sendPushToUser: async () => ({ delivered: true }) } as any;
  const tracking = new TrackingService(mockPrisma, mockAudit, mockNotify);

  const geofenceRes = await tracking.processRiderTelemetry({
    riderId: 'rider-1',
    orderId: 'ord-1',
    latitude: 6.6021,
    longitude: 3.3516,
  });

  assert.equal(geofenceRes.rejected, false);
  assert.equal(geofenceRes.geofenceEvent?.zone, 'DROPOFF_150M');
  assert.equal(geofenceRes.geofenceEvent?.triggerOtpModal, true);
  assert.equal(geofenceRes.geofenceEvent?.ussdString, '*5573*1*28500*8821#');
  assert.equal(updatedOrderGeofence, 'AT_DROPOFF_150M');
  assert.equal(updatedStopStatus, StopStatus.ARRIVED);

  const spoofRes = await tracking.processRiderTelemetry({
    riderId: 'rider-1',
    orderId: 'ord-1',
    latitude: 6.4474,
    longitude: 3.4723,
  });

  assert.equal(spoofRes.rejected, true);
  assert.equal(spoofRes.reason, 'VELOCITY_SPOOF_DETECTED');
  assert.ok(spoofRes.speedKmh > 140);
  assert.equal(updatedSpoofFlags, 1);
});

test('UploadsService stores valid PNG base64 media and rejects unsupported MIME types', async () => {
  const uploads = new UploadsService();
  const samplePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

  const saved = await uploads.saveBase64Media('user_test', {
    folder: 'pod',
    mimeType: 'image/png',
    base64Data: samplePngBase64,
  });

  assert.equal(saved.success, true);
  assert.match(saved.url, /^http:\/\/localhost:4000\/uploads\/pod\/user_test-.*\.png$/);

  const fileOnDisk = path.join(process.cwd(), saved.relativePath.replace(/^\//, ''));
  assert.equal(fs.existsSync(fileOnDisk), true);
  fs.unlinkSync(fileOnDisk);

  await assert.rejects(
    uploads.saveBase64Media('user_test', {
      folder: 'pod',
      mimeType: 'application/x-msdownload',
      base64Data: samplePngBase64,
    }),
  );
});

test('RiderService.reportDelayFlag emits socket delay event and push alert for assigned rider', async () => {
  const emitted: Array<{ room: string; event: string; payload: any }> = [];
  let pushedTitle = '';

  const mockPrisma = {
    deliveryOrder: {
      findFirst: async () => ({
        id: 'ord-delay-1',
        orderNumber: 'AP-7721',
        senderId: 'cust-1',
        riderId: 'rider-1',
      }),
    },
  } as any;

  const mockGateway = {
    server: {
      to: (room: string) => ({
        emit: (event: string, payload: any) => emitted.push({ room, event, payload }),
      }),
    },
  } as any;

  const mockNotify = {
    sendPushToUser: async (_u: string, title: string) => {
      pushedTitle = title;
      return { delivered: true };
    },
  } as any;

  const riderService = new RiderService(
    mockPrisma,
    { log: async () => {} } as any,
    mockGateway,
    {} as any,
    mockNotify,
  );

  const res = await riderService.reportDelayFlag('rider-1', 'ord-delay-1', {
    flagType: 'ESTATE_GATE_HOLD',
  });

  assert.equal(res.success, true);
  assert.equal(res.event.flagType, 'ESTATE_GATE_HOLD');
  assert.equal(emitted.length, 2);
  assert.equal(emitted[0].event, 'orderDelayReported');
  assert.equal(pushedTitle, 'Route Update: AP-7721');
});
