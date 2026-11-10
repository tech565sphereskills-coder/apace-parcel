# Apace Parcel Backend

Enterprise NestJS TypeScript backend powering the Apace Parcel on-demand logistics and digital stored-value wallet ecosystem in Nigeria.

## Features

- **Authentication & Security**: JWT Authentication, bcrypt password hashing, customer & rider roles.
- **Identity & KYC Module**: NIMC 11-digit NIN & BVN verification, Tier 1 (₦50k), Tier 2 (₦500k), and Tier 3 (₦5M) daily limits.
- **Wallet & Fintech Engine**: ACID-compliant transactions, automated Moniepoint MFB virtual account webhooks, Paystack card top-ups, and bank withdrawals.
- **Dispatch & Orders Engine**: Instant Bike, Express Car, Mini-Van, and Interstate Cargo bookings, 4-digit handover OTP security, distance fare matrix, and rider tipping.
- **Real-Time Tracking (WebSockets)**: Socket.io gateway broadcasting live rider GPS coordinates every 3-5 seconds to customer tracking screens.
- **Interactive Swagger UI**: Full interactive API documentation and testing at `http://localhost:4000/api/docs`.

## Quick Start

1. Install dependencies:
   ```bash
   npm install
   ```

2. Configure environment:
   Update `.env` with your PostgreSQL database connection string:
   ```env
   DATABASE_URL="postgresql://user:password@localhost:5432/apace_parcel?schema=public"
   ```

3. Generate Prisma client & run migrations:
   ```bash
   npm run prisma:generate
   npm run prisma:migrate
   ```

4. Start development server:
   ```bash
   npm run start:dev
   ```

5. Open Swagger Documentation:
   Visit `http://localhost:4000/api/docs` in your browser.

