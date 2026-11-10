# Apace Parcel

Full-stack express logistics, AI WhatsApp-to-dispatch automation, COD Naira escrow wallet, and real-time rider navigation platform built with **Flutter**, **NestJS (TypeScript)**, **Prisma (PostgreSQL)**, and **Socket.IO**.

---

## Core Capabilities

- **AI "Magic Paste" Snap-to-Dispatch**: Parses raw WhatsApp / Instagram DM order texts into structured pickup/dropoff locations, Nigerian landmarks, recipient contacts, and COD escrow amounts in one tap.
- **Self-Healing Rider Dispatch Auction**: Cascades live 15-second WebSocket dispatch offers (`Socket.IO`) to nearby online riders, automatically falling back to the next rider on decline or timeout.
- **Turn-by-Turn Rider Navigation & Delay Broadcast**: Deep links riders directly into **Google Maps**, **Waze**, **Apple / System Maps**, or **WhatsApp recipient pin requests** via [`NavigationLauncher`](lib/services/navigation_launcher.dart), plus one-tap traffic delay flags reflected on customer tracking.
- **COD Escrow & Naira Wallet Engine**: Moniepoint MFB virtual account deposits, Paystack card top-ups, 4-digit PIN authorization, Tiered KYC/BVN verification, and 4-digit handover OTP escrow release.
- **Live Customer Telemetry & Waybills**: Custom animated bottom navigation bar, real-time corridor route map, multi-stop support, PDF waybill generation, and dispute resolution.

---

## UI Design & Prototype (Figma)

- **Design System & Editable Screens:** [Apace Parcel — UI Design System & Screens](https://www.figma.com/design/YMxcoapd2qDKBqLO58yzQc)
- **Interactive Clickable Prototype:** [Apace Parcel — Interactive Prototype](https://www.figma.com/make/DcPouKWJYVdqmr7gXQJnht)
- **End-to-End Dispatch & Navigation Flow:** [Apace Parcel — FigJam Architecture Flow](https://www.figma.com/board/tlsM6290UXRs68yXcZ3o2C)

---

## Repository Structure

```text
.
├── lib/                    # Flutter client (screens, widgets, services, models, design tokens)
├── test/                   # Flutter widget & service tests
├── assets/images/          # App image & SVG assets
├── android/ & ios/         # Mobile platform configs & deep-link intents
└── backend/                # NestJS TypeScript API + WebSocket server
    ├── prisma/             # PostgreSQL Prisma schema
    ├── src/                # Modules: auth, orders, dispatch, tracking, wallet, rider, kyc, admin, ...
    ├── test/               # Backend unit test suite
    └── .env.example        # Environment variable template
```

---

## Getting Started

### 1. Backend API (NestJS + Prisma)

```bash
cd backend
cp .env.example .env
npm install
npm run prisma:generate
npm run prisma:migrate
npm run build
npm run start:dev
```

- API base URL: `http://localhost:4000/api`
- Swagger docs: `http://localhost:4000/api/docs`
- Run backend unit tests:
  ```bash
  cd backend
  npm test
  ```

### 2. Flutter Mobile & Web Client

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

To test on Flutter Web locally alongside the backend:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8085
```
