# Project Initialization Guide

This file explains how to initialize and run the Hamme project from a fresh clone.

## Prerequisites

Install these first:

- Flutter 3.29.x stable
- Dart 3.7.x
- Node.js 20+
- npm 10+
- MongoDB local server or MongoDB Atlas
- Android Studio if you want Android emulator/device builds
- Xcode (macOS only) if you want iOS simulator/device builds

Windows desktop is not a supported build target — push notifications (Firebase)
don't support it, so the `windows/` platform folder was removed.

## Project Structure

This repository contains two apps:

- Flutter frontend in the repository root
- Express backend in [backend/package.json](backend/package.json)

## 1. Clone And Enter The Project

```bash
git clone https://github.com/mhdafnan2003/Hamme-Flutter-App.git
cd Hamme-Flutter-App
```

## 2. Configure Frontend Environment

Create a local frontend env file from the example:

```bash
copy .env.example .env
```

Use the API base URL that matches your target:

- Android emulator: `http://10.0.2.2:3000/api/v1`
- Chrome or Edge: `http://localhost:3000/api/v1`

Recommended `.env` values for desktop or web:

```env
API_BASE_URL=http://localhost:3000/api/v1
SHARE_LINK_BASE=https://app.hamme.link/poll
APP_SCHEME=hamme
APP_HOST=app.hamme.link
```

## 3. Configure Backend Environment

Create the backend env file:

```bash
cd backend
copy .env.example .env
cd ..
```

Minimum backend variables to review:

- `MONGODB_URI`
- `JWT_ACCESS_SECRET`
- `JWT_REFRESH_SECRET`
- `PORT`

Example for local MongoDB:

```env
NODE_ENV=development
PORT=3000
MONGODB_URI=mongodb://127.0.0.1:27017/hamme
CLIENT_ORIGIN=http://localhost:3000
JWT_ACCESS_SECRET=replace-with-a-strong-secret
JWT_REFRESH_SECRET=replace-with-a-second-strong-secret
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=30d
ENABLE_SOCKETS=true
```

## 4. Install Dependencies

Install Flutter packages:

```bash
flutter pub get
```

Install backend packages:

```bash
cd backend
npm install
cd ..
```

## 5. Generate Flutter Model Code

Run this once after setup, and again whenever you change Freezed or JSON model classes:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 6. Add Missing Flutter Platforms If Needed

If your local clone does not have the target platform you want to use, generate it with:

```bash
flutter create --platforms=web .
```

You only need to do this if that folder is missing.

## 7. Start MongoDB

Choose one:

- Start a local MongoDB instance
- Use MongoDB Atlas and set `MONGODB_URI` accordingly

## 8. Start The Backend

```bash
cd backend
npm run dev
```

Expected health endpoint:

```bash
http://localhost:3000/health
```

Expected response:

```json
{"status":"ok"}
```

## 9. Run The Flutter App

Check available targets:

```bash
flutter devices
```

Run on Chrome:

```bash
flutter run -d chrome
```

Run on Android emulator:

```bash
flutter run -d android
```

For Android, make sure `.env` uses `http://10.0.2.2:3000/api/v1` instead of `localhost`.

## 10. Validate The Setup

Frontend:

```bash
flutter analyze
```

Backend:

```bash
cd backend
npm run check
cd ..
```

## Common Issues

### Port 3000 Already In Use

If `npm run dev` fails with `EADDRINUSE`, another process is already using port 3000.

Either:

- Stop the process using port 3000
- Change `PORT` in [backend/.env](backend/.env) and update `API_BASE_URL` in [.env](.env)

### Flutter Web Not Configured

If Flutter says the app is not configured for web, run:

```bash
flutter create --platforms=web .
```

### Android Toolchain Problems

If Android builds do not start, run:

```bash
flutter doctor -v
```

Then resolve SDK, emulator, or license issues shown there.

### Riverpod Or Package Compatibility

This project is pinned to package versions that work with Flutter 3.29. If you upgrade Flutter, review package versions before bumping them.

## First Successful Run Checklist

- `.env` created in the repo root
- `backend/.env` created
- MongoDB running or Atlas URI configured
- `flutter pub get` completed
- `npm install` completed in `backend`
- backend started with `npm run dev`
- app started with `flutter run -d chrome` or `flutter run -d android`

## Recommended First Command Sequence

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
cd backend
npm install
npm run dev
```

In a second terminal:

```bash
cd Hamme-Flutter-App
flutter run -d chrome
```
