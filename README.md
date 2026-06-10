# Hamme

Production-ready full-stack starter for a Flutter mobile app and an Express + MongoDB backend.

## Stack

### Frontend

- Flutter 3.29 stable
- Riverpod for state management
- go_router for routing and deep-link-ready paths
- http for API access
- freezed + json_serializable for models
- flutter_secure_storage for JWT persistence
- image_picker and cached_network_image for profile media handling
- flutter_dotenv for environment configuration

### Backend

- Node.js 20 + Express
- MVC + service layer organization
- MongoDB with Mongoose
- JWT access and refresh tokens
- express-validator validation
- express-rate-limit, cors, helmet, and morgan middleware
- Optional Socket.IO match notifications scaffold

## Structure

```text
.
├─ lib/
│  ├─ core/
│  ├─ features/
│  │  ├─ auth/
│  │  ├─ onboarding/
│  │  ├─ profile/
│  │  ├─ interactions/
│  │  └─ matches/
│  ├─ models/
│  ├─ providers/
│  └─ routes/
├─ backend/
│  └─ src/
│     ├─ config/
│     ├─ controllers/
│     ├─ middleware/
│     ├─ models/
│     ├─ routes/
│     ├─ services/
│     └─ utils/
└─ android/ ios/
```

## Implemented Starter Features

- Signup, login, logout, session restore, and current-user retrieval
- Profile creation fields for name, email, Instagram ID, and profile image URL
- Anonymous interaction submission using shareable profile links
- Match detection when two users send the same interaction type to each other
- Match listing endpoint and Flutter screen
- Prepared deep-link routes for `/u/:shareCode` plus native mobile scheme registration
- Secure token persistence on device using flutter_secure_storage

## Environment Files

### Flutter

- Copy `.env.example` to `.env` if you want custom values.
- Default Android emulator API base URL is already set to `http://10.0.2.2:3000/api/v1`.

### Backend

- Copy `backend/.env.example` to `backend/.env` and replace all placeholder values.
- For Vercel, set all values from `backend/.env.example` in the backend project's environment variables.
- `ENABLE_SOCKETS` should stay `false` on Vercel because the backend is deployed as serverless functions.

### Client

- Copy `client/.env.example` to `client/.env` and point `VITE_API_BASE_URL` at your deployed backend.
- Set `VITE_FLUTTER_WEB_URL` only if you still use the Flutter web fallback from the React funnel.

## Local Development

### 1. Start MongoDB

Use a local MongoDB instance or MongoDB Atlas.

### 2. Start the backend

```bash
cd backend
npm run dev
```

### 3. Start the React funnel

```bash
cd client
npm install
npm run dev
```

### 4. Run the Flutter app

```bash
flutter pub get
flutter run
```

## Vercel Deployment

Deploy `client` and `backend` as separate Vercel projects.

### Backend project

- Root directory: `backend`
- Framework preset: `Other`
- Entrypoint: `api/index.js` via `backend/vercel.json`
- Required env vars: everything in `backend/.env.example`

### Client project

- Root directory: `client`
- Framework preset: `Vite`
- SPA rewrites are handled by `client/vercel.json`
- Required env vars: everything in `client/.env.example`

## Code Generation

Run this whenever you change Freezed or JSON model definitions:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Key API Routes

- `POST /api/v1/auth/signup`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`
- `GET /api/v1/profiles/me`
- `PATCH /api/v1/profiles/me`
- `GET /api/v1/profiles/public/:shareCode`
- `POST /api/v1/interactions`
- `GET /api/v1/interactions/matches`

## Notes

- Public profile responses intentionally avoid exposing the target user's email.
- The Flutter profile screen includes local image picking for the future upload flow while the backend starter currently accepts a profile image URL.
- Socket.IO is scaffolded for real-time match notifications but the Flutter client connection is not yet wired.
