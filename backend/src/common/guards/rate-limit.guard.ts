import { Injectable, CanActivate, ExecutionContext, HttpException, HttpStatus } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RATE_LIMIT_KEY, RateLimitConfig } from '../decorators/rate-limit.decorator';

@Injectable()
export class RateLimitGuard implements CanActivate {
  private readonly buckets = new Map<string, number[]>();
  private lastCleanup = Date.now();

  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const config = this.reflector.getAllAndOverride<RateLimitConfig>(RATE_LIMIT_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    const limit = config?.limit ?? 120;
    const windowMs = (config?.windowSeconds ?? 60) * 1000;

    const request = context.switchToHttp().getRequest();
    const ip = request.ip || request.headers['x-forwarded-for'] || 'unknown';
    const userId = request.user?.id || 'anon';
    const route = `${request.method}:${request.route?.path || request.url}`;
    const key = `${route}:${ip}:${userId}`;

    const now = Date.now();
    this.pruneIfNeeded(now, windowMs);

    const existing = this.buckets.get(key) || [];
    const active = existing.filter((ts) => now - ts < windowMs);

    if (active.length >= limit) {
      const oldest = active[0];
      const retryAfterSeconds = Math.max(1, Math.ceil((oldest + windowMs - now) / 1000));
      throw new HttpException(
        {
          statusCode: HttpStatus.TOO_MANY_REQUESTS,
          message: `Too many requests. Please wait ${retryAfterSeconds} second(s) and try again.`,
          retryAfterSeconds,
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    active.push(now);
    this.buckets.set(key, active);
    return true;
  }

  private pruneIfNeeded(now: number, maxAgeMs: number) {
    if (now - this.lastCleanup < 60000) return;
    this.lastCleanup = now;
    for (const [k, timestamps] of this.buckets.entries()) {
      const valid = timestamps.filter((ts) => now - ts < Math.max(maxAgeMs, 300000));
      if (valid.length === 0) {
        this.buckets.delete(k);
      } else {
        this.buckets.set(k, valid);
      }
    }
  }
}

