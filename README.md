# Basket Coach

Monorepo (pnpm workspaces): Next.js PWA + Supabase. See `apps/web` for the frontend and `supabase/` for SQL migrations.

## Quickstart (WSL Ubuntu 22.04)
1. Install pnpm: `npm i -g pnpm`
2. Copy `.env.example` → `apps/web/.env.local` and fill your Supabase keys.
3. Install deps: `pnpm install`
4. Run dev server: `pnpm dev`

## Testing
- Unit tests: Jest + React Testing Library. Run `pnpm test`.

## CI
- GitHub Actions runs lint, typecheck, tests, and build on PRs.

## Deploy
- Connect this repo to **Vercel** (Next.js) and **Supabase** (database/storage). See notes in the main plan doc.

## Commands to tun locally
// In WSL (Ubuntu 22.04)
// 1) Clone your new repo (after pushing to GitHub)
// 2) Inside repo root:
pnpm install

// 3) Create env file for web app
cp .env.example apps/web/.env.local
// Fill in NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY

// 4) Start dev server
pnpm dev

// 5) Run tests
pnpm test

// 6) (Optional) Apply DB schema using Supabase Studio SQL editor or supabase CLI
// paste supabase/migrations/0001_init.sql and run