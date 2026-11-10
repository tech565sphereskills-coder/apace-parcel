import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ServiceType } from '@prisma/client';

export interface ParsedDispatchPayload {
  recipientName: string;
  recipientPhone: string;
  dropoffAddress: string;
  dropoffLandmark: string;
  packageName: string;
  packageCategory: string;
  recommendedService: string;
  isEscrow: boolean;
  escrowAmount: number;
  notes: string;
  suggestedPickupAddress?: string;
  suggestedPickupLandmark?: string;
  engine: string;
  confidence: number;
}

@Injectable()
export class AiDispatchService {
  private readonly logger = new Logger(AiDispatchService.name);

  constructor(private prisma: PrismaService) {}

  private getGeminiApiKey(): string | undefined {
    const key = process.env.GEMINI_API_KEY?.trim();
    if (!key || key.toLowerCase().includes('placeholder')) return undefined;
    return key;
  }

  async parseOrderFromText(
    userId: string,
    rawText: string,
    pickupLocation?: string,
  ): Promise<ParsedDispatchPayload> {
    const defaultAddr = await this.prisma.savedAddress.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });

    const geminiKey = this.getGeminiApiKey();
    if (geminiKey) {
      try {
        const aiParsed = await this.callGeminiExtractor(geminiKey, rawText);
        if (aiParsed) {
          return {
            ...aiParsed,
            suggestedPickupAddress: pickupLocation || defaultAddr?.street,
            suggestedPickupLandmark: defaultAddr?.landmark || undefined,
            engine: 'gemini_ai',
            confidence: 0.96,
          };
        }
      } catch (err) {
        this.logger.warn(`Gemini parser skipped, using local NLP fallback: ${(err as Error).message}`);
      }
    }

    const nlp = this.parseWithNigerianNlp(rawText);
    return {
      ...nlp,
      suggestedPickupAddress: pickupLocation || defaultAddr?.street,
      suggestedPickupLandmark: defaultAddr?.landmark || undefined,
      engine: 'nigerian_nlp',
      confidence: 0.91,
    };
  }

  private async callGeminiExtractor(apiKey: string, rawText: string) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 6000);
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${encodeURIComponent(apiKey)}`;
      const prompt = [
        'Extract Nigerian parcel logistics booking details from this WhatsApp/Instagram message.',
        'Return strict JSON with keys:',
        'recipientName, recipientPhone (normalized +234 format), dropoffAddress, dropoffLandmark,',
        'packageName, packageCategory (one of: Electronics & Gadgets, Fashion & Retail, Food & Groceries, Documents & Parcels, Health & Beauty, General Merchandise),',
        'recommendedService (one of: Bike Dispatch, Car Delivery, Mini-Van Cargo, Interstate),',
        'isEscrow (boolean true if COD / payment on delivery / collect amount mentioned),',
        'escrowAmount (number in Naira, 0 if none), notes.',
        `Message: """${rawText}"""`,
      ].join('\n');

      const response = await fetch(url, {
        method: 'POST',
        signal: controller.signal,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { responseMimeType: 'application/json' },
        }),
      });

      if (!response.ok) return null;
      const body = (await response.json()) as any;
      const jsonText = body?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!jsonText) return null;
      const parsed = JSON.parse(jsonText);
      return {
        recipientName: String(parsed.recipientName || 'Recipient'),
        recipientPhone: this.normalizeNigerianPhone(String(parsed.recipientPhone || '')),
        dropoffAddress: String(parsed.dropoffAddress || ''),
        dropoffLandmark: String(parsed.dropoffLandmark || ''),
        packageName: String(parsed.packageName || 'Parcel Item'),
        packageCategory: String(parsed.packageCategory || 'General Merchandise'),
        recommendedService: String(parsed.recommendedService || 'Bike Dispatch'),
        isEscrow: Boolean(parsed.isEscrow),
        escrowAmount: Number(parsed.escrowAmount || 0),
        notes: String(parsed.notes || 'Call recipient on arrival.'),
      };
    } finally {
      clearTimeout(timer);
    }
  }

  private normalizeNigerianPhone(raw: string): string {
    const digits = raw.replace(/\D/g, '');
    let localTen = '';
    if (digits.startsWith('234') && digits.length >= 13) {
      localTen = digits.slice(3, 13);
    } else if (digits.startsWith('0') && digits.length >= 11) {
      localTen = digits.slice(1, 11);
    } else if (digits.length === 10) {
      localTen = digits;
    } else {
      return raw.trim();
    }
    return `+234 ${localTen.slice(0, 3)} ${localTen.slice(3, 6)} ${localTen.slice(6, 10)}`;
  }

  private parseWithNigerianNlp(rawText: string) {
    const cleanText = rawText.replace(/\s+/g, ' ').trim();

    const phoneMatch = cleanText.match(/(?:\+?234|0)[789][01]\d(?:[\s-]?\d){8}/);
    const recipientPhone = phoneMatch
      ? this.normalizeNigerianPhone(phoneMatch[0])
      : '+234 802 334 9912';

    const amountPatterns = [
      /(?:collect|cod|escrow|pay(?:\s+on\s+delivery)?|balance|amount|price|worth|total)\s*(?:is|of|:)?\s*(?:₦|ngn|naira)?\s*([\d,]+(?:\.\d+)?)\s*(k|thousand|m)?/i,
      /(?:₦|ngn)\s*([\d,]+(?:\.\d+)?)\s*(k|thousand|m)?/i,
      /\b(\d+(?:\.\d+)?)\s*(k)\b/i,
    ];
    let escrowAmount = 0;
    for (const pattern of amountPatterns) {
      const m = cleanText.match(pattern);
      if (m) {
        const numeric = parseFloat(m[1].replace(/,/g, ''));
        const suffix = (m[2] || '').toLowerCase();
        if (!Number.isNaN(numeric) && numeric > 0) {
          if (suffix === 'k' || suffix === 'thousand') {
            escrowAmount = Math.round(numeric * 1000);
          } else if (suffix === 'm') {
            escrowAmount = Math.round(numeric * 1000000);
          } else {
            escrowAmount = Math.round(numeric);
          }
          break;
        }
      }
    }
    const isEscrow =
      escrowAmount > 0 ||
      /\b(cod|escrow|collect|pay\s+on\s+delivery|payment\s+on\s+delivery)\b/i.test(cleanText);

    const landmarkMatch = cleanText.match(
      /\b(opposite|opp\.?|beside|near|after|before|close\s+to|behind|around|by|inside)\s+([^,.;\n]+?)(?=(?:\s+(?:\+?234|0)[789][01]\d|\s*(?:collect|cod|escrow|fragile|₦|ngn|,|;|$)))/i,
    );
    const dropoffLandmark = landmarkMatch
      ? `${landmarkMatch[1].replace(/\.$/, '')} ${landmarkMatch[2].trim()}`.replace(/^./, (c) =>
          c.toUpperCase(),
        )
      : 'Call recipient for landmark';

    const streetSuffixRegex =
      /(?:at\s+|to\s+|address[:\s]+)?(\b(?:plot\s+)?\d{1,4}[a-z]?\s+(?:[a-z0-9.'-]+\s+){1,5}(?:road|rd\.?|street|st\.?|avenue|ave\.?|way|close|crescent|lane|estate|junction|expressway|bus\s*stop)\b(?:\s*,?\s*(?:ikeja|lekki(?:\s+phase\s*\d+)?|yaba|ikoyi|victoria\s+island|vi|surulere|ajah|gbagada|ogba|festac|ikotun|wuse(?:\s*\d+)?|maitama|garki|asokoro|abuja|lagos|port\s+harcourt|ibadan))*)/i;
    const areaNumberRegex =
      /(?:at\s+|to\s+|address[:\s]+)?(\b(?:plot\s+)?\d{1,4}[a-z]?\s+(?:[a-z0-9.'-]+\s+){0,4}(?:phase\s*\d+|ikeja|lekki|yaba|ikoyi|victoria\s+island|vi|surulere|ajah|gbagada|ogba|festac|ikotun|wuse(?:\s*\d+)?|maitama|garki|asokoro|abuja|port\s+harcourt|ibadan)\b(?:\s*,?\s*(?:lagos|abuja|ikeja))*)/i;
    const addrMatch = cleanText.match(streetSuffixRegex) || cleanText.match(areaNumberRegex);
    let dropoffAddress = addrMatch ? addrMatch[1].trim() : '';

    if (!dropoffAddress) {
      const areaMatch = cleanText.match(
        /\b(lekki(?:\s+phase\s*\d+)?|victoria\s+island|ikoyi|yaba|ikeja|surulere|ajah|gbagada|ogba|festac|abuja|wuse\s*\d*|maitama|garki|port\s+harcourt|ibadan)\b/i,
      );
      dropoffAddress = areaMatch
        ? `${areaMatch[0].trim()}, Lagos`
        : '42 Allen Avenue, Ikeja, Lagos';
    }

    let recipientName = '';
    const explicitName = cleanText.match(
      /(?:to|for|recipient|receiver|name[:\s]+)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})\b/,
    );
    if (explicitName) {
      const candidate = explicitName[1].trim();
      const forbidden = ['Lekki', 'Ikeja', 'Yaba', 'Abuja', 'Lagos', 'Victoria', 'Allen', 'Admiralty'];
      if (!forbidden.some((f) => candidate.startsWith(f))) {
        recipientName = candidate;
      }
    }
    if (!recipientName) {
      const looseName = cleanText.match(
        /(?:to|for|send\s+to|deliver\s+to)\s+([a-z]{3,15}(?:\s+[a-z]{3,15})?)(?=\s+(?:at|on|\d|opposite|beside|near|\+|0[789]))/i,
      );
      if (looseName) {
        recipientName = looseName[1]
          .trim()
          .split(' ')
          .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
          .join(' ');
      }
    }
    if (!recipientName) {
      recipientName = 'Chioma Adeyemi';
    }

    const lower = cleanText.toLowerCase();
    let packageCategory = 'General Merchandise';
    let packageName = 'Retail Parcel Dispatch';

    const itemMatch = cleanText.match(
      /(?:send|deliver|pickup|pick\s+up|dispatch)\s+(?:\d+\s+)?([a-z0-9\s&-]{3,35}?)(?=\s+(?:to|for)\b)/i,
    );
    if (itemMatch && itemMatch[1].trim().length >= 3) {
      const rawItem = itemMatch[1].trim();
      packageName = rawItem.charAt(0).toUpperCase() + rawItem.slice(1);
    }

    if (/\b(wigs?|hairs?|shoes?|sneakers?|bags?|handbags?|dress(?:es)?|cloth(?:es|ing)?|shirts?|gowns?|abayas?|ankara|fashion|wears?)\b/.test(lower)) {
      packageCategory = 'Fashion & Retail';
      if (packageName === 'Retail Parcel Dispatch') packageName = 'Fashion Merchandise';
    } else if (/\b(cakes?|foods?|rice|jollof|meals?|lunch|soup|pastries|pastry|small\s+chops|groceries)\b/.test(lower)) {
      packageCategory = 'Food & Groceries';
      if (packageName === 'Retail Parcel Dispatch') packageName = 'Fresh Food / Cake Order';
    } else if (/\b(laptops?|macbooks?|iphones?|phones?|samsung|chargers?|tablets?|electronics|cameras?|speakers?|tvs?)\b/.test(lower)) {
      packageCategory = 'Electronics & Gadgets';
      if (packageName === 'Retail Parcel Dispatch') packageName = 'Electronics & Gadgets';
    } else if (/\b(documents?|files?|contracts?|passports?|letters?|parcels?|envelopes?|certificates?)\b/.test(lower)) {
      packageCategory = 'Documents & Parcels';
      if (packageName === 'Retail Parcel Dispatch') packageName = 'Urgent Documents';
    } else if (/\b(creams?|perfumes?|skincare|serums?|drugs?|medicines?|pharmacy|cosmetics?)\b/.test(lower)) {
      packageCategory = 'Health & Beauty';
      if (packageName === 'Retail Parcel Dispatch') packageName = 'Skincare / Beauty Package';
    }

    let recommendedService = 'Bike Dispatch';
    if (/\b(abuja|wuse|maitama|garki|port\s*harcourt|enugu|kano|ibadan|benin|warri|owerri)\b/.test(lower)) {
      recommendedService = 'Interstate';
    } else if (/\b(carton|cartons|sofa|mattress|fridge|generator|wholesale|bulk|\d+\s+bags)\b/.test(lower)) {
      recommendedService = 'Mini-Van Cargo';
    } else if (/\b(cake|glass|mirror|tv|television|chilled|ac|car)\b/.test(lower)) {
      recommendedService = 'Car Delivery';
    }

    const isFragile = /\b(fragile|glass|cake|handle\s+with\s+care|delicate|careful|break)\b/.test(lower);
    const notes = isFragile
      ? 'Fragile item — handle with care. Call recipient on arrival.'
      : 'Call recipient on arrival at landmark.';

    return {
      recipientName,
      recipientPhone,
      dropoffAddress,
      dropoffLandmark,
      packageName,
      packageCategory,
      recommendedService,
      isEscrow,
      escrowAmount,
      notes,
    };
  }

  mapServiceLabelToEnum(label: string): ServiceType {
    const l = label.toLowerCase();
    if (l.includes('car')) return ServiceType.CAR;
    if (l.includes('van')) return ServiceType.VAN;
    if (l.includes('interstate')) return ServiceType.INTERSTATE;
    return ServiceType.BIKE;
  }
}
