import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private prisma: PrismaService) {}

  async registerDeviceToken(userId: string, token: string, platform: string) {
    const record = await this.prisma.deviceToken.upsert({
      where: { token },
      update: { userId, platform },
      create: { userId, token, platform },
    });
    return { success: true, deviceToken: record };
  }

  async unregisterDeviceToken(userId: string, token: string) {
    await this.prisma.deviceToken.deleteMany({
      where: { userId, token },
    });
    return { success: true };
  }

  async getHistory(userId: string) {
    return this.prisma.notificationLog.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 40,
    });
  }

  async markRead(userId: string, id: string) {
    await this.prisma.notificationLog.updateMany({
      where: { id, userId },
      data: { isRead: true },
    });
    return { success: true };
  }

  async sendPushToUser(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, any>,
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { notifyPush: true },
    });

    if (user && !user.notifyPush) {
      return { delivered: false, skipped: 'user_opted_out' };
    }

    const tokens = await this.prisma.deviceToken.findMany({
      where: { userId },
      select: { token: true, platform: true },
    });

    const fcmKey = process.env.FCM_SERVER_KEY?.trim();
    const isLiveFcm = fcmKey && !fcmKey.toLowerCase().includes('placeholder') && tokens.length > 0;
    let provider = 'fcm_sandbox';

    if (isLiveFcm) {
      try {
        await Promise.all(
          tokens.map((t) =>
            fetch('https://fcm.googleapis.com/fcm/send', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Authorization: `key=${fcmKey}`,
              },
              body: JSON.stringify({
                to: t.token,
                notification: { title, body, sound: 'default' },
                data: data || {},
              }),
            }),
          ),
        );
        provider = 'fcm_live';
      } catch (err) {
        this.logger.warn(`FCM push fallback for ${userId}: ${(err as Error).message}`);
      }
    } else {
      this.logger.log(`[SANDBOX FCM PUSH] User=${userId} | ${title} :: ${body}`);
    }

    const log = await this.prisma.notificationLog.create({
      data: {
        userId,
        title,
        body,
        channel: 'PUSH',
        provider,
        metadata: data || {},
      },
    });

    return { delivered: true, provider, notificationId: log.id };
  }
}
