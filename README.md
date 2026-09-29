# Mohalla Mart

Discover locally, chat directly, and buy nearby. Mohalla Mart connects customers with neighborhood shops so they can discover local products, ask questions, chat with shopkeepers, and request reservations. The app does not process online payments.

## Features and roles

- **Customers:** browse approved shops and products, search by category and location, send product inquiries, chat with shopkeepers, request reservations, and post nearby product requests.
- **Shopkeepers:** manage a shop and its products, respond to customer inquiries and nearby requests, chat, and manage reservations.
- **Admins:** review users, shops, products, and reports. New shop and product listings require approval before customer discovery.

Customer, shopkeeper, and admin data is persisted in Supabase. Row Level Security controls access to the database; customer listings show only approved and active shops/products.

## Technology

- React 19, TypeScript, Vite, and React Router
- Supabase Auth, Postgres, Row Level Security, Realtime, and Storage
- npm with the committed `package-lock.json`

## Run locally

Requirements: Node.js compatible with the versions in `package.json` and npm.

```sh
npm ci
```

Copy `.env.example` to `.env.local` (PowerShell: `Copy-Item .env.example .env.local`) and set:

```dotenv
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=your-supabase-publishable-key
```

Use the Supabase project's public URL and publishable/anon key. These `VITE_` values are included in the browser app; never put a service-role key or other server secret here. With no values set, the app displays its Supabase configuration message and data-backed features are unavailable.

```sh
npm run dev
```

## Supabase setup and demo

1. Create a Supabase project and apply every SQL migration in `supabase/migrations/` in filename order. See [ADMIN_SETUP.md](./ADMIN_SETUP.md) for migration, first-admin, approval, and demo instructions.
2. Set the environment variables above for local development.
3. In Supabase Auth URL Configuration, allow the local URL shown by Vite and the deployed app URL. Configure email delivery/confirmation for the sign-in and password-reset flows.
4. The `supabase/seed.sql` script creates fictional shops, products, and sample activity. It requires one existing Auth-backed shopkeeper named `Mohalla Mart Demo Shopkeeper` and one customer named `Mohalla Mart Demo Customer`; create them through signup, then run the seed in Supabase SQL Editor. Seeded listings start pending and need admin approval. The local Supabase CLI seed hook is disabled because those Auth profiles must exist first; the seed file remains available for manual demo setup. The project does not define shared demo passwords or built-in demo credentials.

The migrations configure the `shop-media` Storage bucket for listing images. RLS limits uploads to the signed-in owner's folder and allows public reads for listing imagery.

## Checks and production build

```sh
npm run lint
npm run build
npm run preview
```

The build runs TypeScript project checks and creates the static site in `dist/`. `npm run preview` serves that built site locally; there is no separate application server or production start command.

## Deploy to Vercel

This is a client-side Vite SPA backed by Supabase, so Vercel can serve it as a static site. The included [`vercel.json`](./vercel.json) rewrites deep links to `index.html` for React Router.

1. Import the GitHub repository into Vercel and use the project root as the Vercel root directory.
2. Set the build command to `npm run build` and the output directory to `dist` (Vercel usually detects these for Vite).
3. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` under Vercel's environment variables for the deployment environments you use. Do not add a service-role key.

5. Deploy, then add the final HTTPS site URL to Supabase Auth's allowed redirect URLs/site URL. Confirm the production URL and password-reset/email confirmation flows.
6. Apply migrations to the Supabase project before using the deployed app. Bootstrap an admin and approve demo or real listings as described in `ADMIN_SETUP.md`.

Vercel hosts only the frontend; Supabase remains the backend/database. `npm run preview` is for local build verification, not the production server command.
# mohalla-mart
