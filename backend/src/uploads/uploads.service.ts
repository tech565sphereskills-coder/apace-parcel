import { Injectable, BadRequestException } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import { UploadMediaDto } from './dto/upload-media.dto';

@Injectable()
export class UploadsService {
  async saveBase64Media(userId: string, dto: UploadMediaDto, requestOrigin?: string) {
    const cleanMime = dto.mimeType.toLowerCase().trim();
    const extMap: Record<string, string> = {
      'image/jpeg': 'jpg',
      'image/jpg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
    };
    const ext = extMap[cleanMime];
    if (!ext) {
      throw new BadRequestException('Only PNG, JPEG, and WEBP image uploads are supported');
    }

    const rawBase64 = dto.base64Data.includes(',')
      ? dto.base64Data.split(',')[1]
      : dto.base64Data;
    const buffer = Buffer.from(rawBase64.trim(), 'base64');

    if (buffer.length === 0) {
      throw new BadRequestException('Uploaded image payload is empty');
    }
    if (buffer.length > 5 * 1024 * 1024) {
      throw new BadRequestException('Media file exceeds 5MB upload limit');
    }

    const folderPath = path.join(process.cwd(), 'uploads', dto.folder);
    await fs.promises.mkdir(folderPath, { recursive: true });

    const safePrefix = userId.replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 12) || 'user';
    const fileName = `${safePrefix}-${Date.now()}-${crypto.randomBytes(4).toString('hex')}.${ext}`;
    const fullPath = path.join(folderPath, fileName);

    await fs.promises.writeFile(fullPath, buffer);

    const origin = (requestOrigin || process.env.APP_URL || 'http://localhost:4000').replace(/\/$/, '');
    const relativePath = `/uploads/${dto.folder}/${fileName}`;

    return {
      success: true,
      url: `${origin}${relativePath}`,
      relativePath,
      mimeType: cleanMime,
      sizeBytes: buffer.length,
      provider: process.env.CLOUD_STORAGE_BUCKET ? 's3_mirror' : 'local_media_vault',
    };
  }
}

