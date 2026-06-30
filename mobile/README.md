# NutriNova AI Mobile

Flutter app for NutriNova AI on Android and iOS.

## 1. Install Flutter

Install Flutter stable from the official Flutter docs, then verify:

```bash
flutter doctor
```

If `ios/` or `android/` folders are missing, generate platform shells once:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter create . --platforms=ios,android
```

## 2. Install Packages

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter pub get
```

## 3. Run In Mock Mode

Real backend mode is the default. Use mock mode only when you want the UI to work without the backend.

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter run --dart-define=MOCK_MODE=true
```

## 4. Connect To Local Backend

Start the backend from the repository root:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit
cp .env.example .env
docker compose build
docker compose up -d
docker compose ps
docker compose run --rm backend python manage.py migrate
docker compose run --rm backend python manage.py seed_core_nutrition
docker compose run --rm backend python manage.py import_usda_fdc_sample
docker compose run --rm backend python manage.py import_openfoodfacts_sample
docker compose run --rm backend python manage.py ensure_local_storage
curl http://localhost:8000/api/health/
```

iOS simulator:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter run -d ios \
  --dart-define=API_BASE_URL=http://localhost:8000
```

Android emulator:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter run -d android \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Physical phone on same Wi-Fi:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit
ipconfig getifaddr en0
```

Add that IP to `DJANGO_ALLOWED_HOSTS` in `.env`, restart the backend, then run:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit
docker compose restart backend
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter run \
  --dart-define=API_BASE_URL=http://YOUR_MAC_LAN_IP:8000
```

Backend and MinIO bind to `0.0.0.0` through Docker Compose. Your real phone and Mac must be on the same Wi-Fi, and phone photo previews also need port `9000` reachable for local MinIO images.

Open backend checks:

```bash
open http://localhost:8000/api/docs/
curl http://localhost:8000/api/health/
```

Native iOS/Android builds do not need CORS. Flutter web does.

### Local Backend URL Cheat Sheet

- iOS simulator: `http://localhost:8000`
- Android emulator: `http://10.0.2.2:8000`
- Physical iPhone/Android phone: `http://YOUR_MAC_LAN_IP:8000`
- Production later: your HTTPS API domain

For a physical phone, keep the phone and Mac on the same Wi-Fi, start Docker on the Mac, and use `ipconfig getifaddr en0` to find the LAN IP.

### Camera, Photos, And Barcode Permissions

The app uses camera/gallery for meal photos and camera access for barcode scan. If the app cannot open camera/gallery:

- iOS: Simulator or device Settings -> Privacy & Security -> Camera/Photos -> allow NutriNova AI.
- Android: Settings -> Apps -> NutriNova AI -> Permissions -> allow Camera and Photos.
- If platform folders were regenerated, confirm `image_picker` and `mobile_scanner` permissions are present in the generated iOS/Android project files.

### Common macOS Phone Testing Issues

- Phone cannot reach backend: use your Mac LAN IP instead of `localhost`.
- Backend rejects the phone request: add the LAN IP to `DJANGO_ALLOWED_HOSTS` and restart the backend.
- Photo preview image does not load: run `make ensure-local-storage` from the repo root and confirm port `9000` is reachable.
- Camera opens black: check simulator/device camera permissions and try a physical device for barcode scanning.
- Android emulator cannot connect: use `10.0.2.2`, not `127.0.0.1`.

## Connected Core Flows

In real backend mode, the mobile app uses backend endpoints for:

- Auth and onboarding profile state
- Food search and food detail
- Manual meal logging from food detail or manual add
- Quick text add parse and confirm
- AI photo scan review, quantity correction, missing-item add, and confirm as meal
- Today dashboard nutrition, today’s meals, habits today, and habit month grid
- Body weight logging and backend-backed dashboard weight trend
- Private custom food creation with `USER_CUSTOM` source badges

## 5. Quality Checks

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
dart format .
flutter analyze
flutter test
```

## Photo Review Flow

1. Open AI photo scan and choose camera or gallery.
2. Uploading calls `POST /api/photos/analyze-meal/`.
3. The app opens the returned analysis at `/photos/review?analysis_id=...`.
4. The review screen loads `GET /api/photos/analyses/{id}/review/`.
5. Quantity plus/minus buttons call the backend increment/decrement endpoints and refresh the nutrition preview.
6. Remove keeps the detected item in history by marking `is_removed=true`.
7. Add missing item searches foods and calls `POST /api/photos/analyses/{id}/add-manual-food/`.
8. Confirm saves only non-removed reviewed items through `POST /api/photos/analyses/{id}/confirm-as-meal/`.

## Screens Included

- Splash
- Login
- Register
- Onboarding profile setup
- Home dashboard
- Food search
- Meal log
- Manual add
- Quick add text
- Custom food creation
- AI photo scan
- Photo review
- Barcode scan
- Recipe builder
- Habit checklist grid
- Analytics
- Profile/settings

## Notes

- Tokens are stored with `flutter_secure_storage`.
- API calls use `Dio`.
- State management uses Riverpod.
- Navigation uses `go_router`.
- Charts use `fl_chart`.
- Camera/gallery uses `image_picker`.
- Barcode scanning uses `mobile_scanner`.
- NutriNova AI is for wellness tracking only and is not a medical diagnosis or treatment tool.
