# Hamme App — Vercel Hosting Guide

## Live URLs

| Service  | Production URL                                    |
|----------|---------------------------------------------------|
| Backend  | https://backend-three-kappa-24.vercel.app         |
| Frontend | https://client-sigma-beryl-15.vercel.app          |

---

## Architecture Overview

```
Flutter Mobile App  ──→  Backend API (Node/Express serverless)
React Web Client    ──→  Backend API (Node/Express serverless)
                              │
                         MongoDB Atlas
                         Cloudinary (images)
```

The backend and frontend are deployed as **two separate Vercel projects** inside the same team (`govindhansv333gmailcoms-projects`).

---

## Prerequisites

- Node.js 18+
- `npx` (ships with Node.js — no global install needed)
- Vercel account with access to the team `govindhansv333gmailcoms-projects`

To log in:
```bash
npx vercel login
```

---

## Deploying the Backend

```bash
cd backend
npx vercel --prod --yes
```

The project is already linked (`backend/.vercel/project.json`). Vercel will build and deploy to:
`https://backend-three-kappa-24.vercel.app`

### How it works

- Entry point: `api/index.js` — a thin Vercel serverless wrapper around the Express app.
- All routes (`/*`) are rewritten to `api/index.js` via `vercel.json`.
- The function connects to MongoDB on each cold start (connection is cached for warm invocations).
- Max function duration: 10 seconds (configurable in `vercel.json`).

---

## Deploying the Frontend

```bash
cd client
npx vercel --prod --yes
```

The project is already linked (`client/.vercel/project.json`). Vercel will run `npm run build` (Vite) and deploy to:
`https://client-sigma-beryl-15.vercel.app`

### How it works

- Built as a static SPA with Vite.
- All routes (`/*`) rewrite to `index.html` for client-side routing.
- The `VITE_API_BASE_URL` env var is baked in at build time.

---

## Environment Variables

### Backend (`backend/.env` → Vercel project settings)

All vars are already set on the Vercel project. To update one:

```bash
cd backend
npx vercel env rm <VAR_NAME> production
npx vercel env add <VAR_NAME> production
```

| Variable               | Purpose                                        |
|------------------------|------------------------------------------------|
| `NODE_ENV`             | `production`                                   |
| `MONGODB_URI`          | MongoDB Atlas connection string                |
| `CLIENT_ORIGIN`        | Comma-separated allowed CORS origins           |
| `PUBLIC_BASE_URL`      | Base URL used in shareable links               |
| `CLOUDINARY_CLOUD_NAME`| Cloudinary cloud name                          |
| `CLOUDINARY_API_KEY`   | Cloudinary API key                             |
| `CLOUDINARY_API_SECRET`| Cloudinary API secret                          |
| `CLOUDINARY_FOLDER`    | Cloudinary upload folder path                  |
| `JWT_ACCESS_SECRET`    | Secret for signing access tokens               |
| `JWT_REFRESH_SECRET`   | Secret for signing refresh tokens              |
| `JWT_ACCESS_TTL`       | Access token lifetime (e.g. `15m`)             |
| `JWT_REFRESH_TTL`      | Refresh token lifetime (e.g. `300d`)           |
| `ENABLE_SOCKETS`       | `true`/`false` — Socket.IO is disabled on Vercel serverless |
| `PENDING_TTL_SECONDS`  | Pending interaction expiry in seconds          |
| `ANONYMOUS_VOTE_BACK_ENABLED` | `false` for count-only anonymous votes; `true` for blurred vote-back cards and matches |
| `API_RATE_LIMIT`        | Requests allowed per IP per 15 minutes; defaults to `1000` |
| `ALLOW_UNVERIFIED_IAP` | **Set to `false` in production**               |
| `ADMIN_API_KEY`        | Secret key for the admin API                   |

> **Note:** `ALLOW_UNVERIFIED_IAP=true` bypasses in-app purchase verification. Always set it to `false` for a live production environment.

### Frontend (`client/.env` → Vercel project settings)

| Variable           | Value                                              |
|--------------------|----------------------------------------------------|
| `VITE_API_BASE_URL`| `https://backend-three-kappa-24.vercel.app/api/v1` |

To update:
```bash
cd client
npx vercel env rm VITE_API_BASE_URL production
npx vercel env add VITE_API_BASE_URL production
# paste the new value when prompted
npx vercel --prod --yes   # redeploy to bake the new value in
```

---

## Linking a New Machine to an Existing Project

The `.vercel/project.json` files store project IDs and must be present. If they are missing (e.g., fresh clone):

```bash
# Backend
cd backend
npx vercel link
# Select: govindhansv333gmailcoms-projects → backend

# Frontend
cd client
npx vercel link
# Select: govindhansv333gmailcoms-projects → client
```

---

## Deploying a Fresh Project (New Vercel Account or New App)

If you need to deploy under a different account or create new projects:

```bash
# Backend
cd backend
npx vercel --prod
# Follow prompts: create new project, name it, set root to ./

# Frontend
cd client
npx vercel --prod
# Follow prompts: create new project, name it, set root to ./
```

Then add all env vars:
```bash
npx vercel env add <VAR_NAME>
```

---

## Adding a Custom Domain

```bash
# Backend
cd backend
npx vercel domains add api.yourdomain.com

# Frontend
cd client
npx vercel domains add yourdomain.com
```

Then update `CLIENT_ORIGIN` on the backend and `VITE_API_BASE_URL` on the frontend to use the new domains, and redeploy both.

---

## Updating Flutter Mobile App API URL

After changing the backend domain, update `lib/utils/constants/api_constants.dart` (or wherever `BASE_URL` is defined) and the `.env` file at the project root, then rebuild the mobile app.

---

## Useful Commands

```bash
# Check who is logged in
npx vercel whoami

# List recent deployments
npx vercel ls

# View deployment logs
npx vercel logs <deployment-url>

# Inspect a deployment
npx vercel inspect <deployment-url>

# Pull env vars to local .env file
npx vercel env pull .env.vercel
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `uri_does_not_exist` errors in Flutter | Run `flutter pub get` in the project root |
| Cold start timeout | Increase `maxDuration` in `backend/vercel.json` (max 60s on hobby plan) |
| CORS errors | Add the new origin to `CLIENT_ORIGIN` env var on the backend and redeploy |
| Env var not picked up by frontend | Env vars starting with `VITE_` are baked at build time — redeploy after changing them |
| Socket.IO not working | Vercel serverless does not support persistent connections; sockets only work in a traditional Node server |
