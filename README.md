# Basket Coach

Monorepo (pnpm workspaces): Next.js PWA + Supabase.

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
- Connect this repo to **Vercel** (Next.js) and **Supabase** (database/storage).