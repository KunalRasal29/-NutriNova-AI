# NutriNova AI Mobile

Flutter app for NutriNova AI on Android and iOS.

## 1. Install Flutter

Install Flutter stable from the official Flutter docs, then verify:

```bash
flutter doctor
```

If `ios/` or `android/` folders are missing, generate platform shells once:

```bash
cd mobile
flutter create . --platforms=ios,android
```

## 2. Install Packages

```bash
cd mobile
flutter pub get
```

## 3. Run In Mock Mode

Mock mode is enabled by default so the UI works without the backend.

```bash
flutter run --dart-define=MOCK_MODE=true
```

## 4. Connect To Local Backend

Start the backend from the repository root:

```bash
cp .env.example .env
make up
make migrate
docker compose run --rm backend python manage.py seed_core_nutrition
```

iOS simulator:

```bash
cd mobile
flutter run \
  --dart-define=MOCK_MODE=false \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Android emulator:

```bash
cd mobile
flutter run \
  --dart-define=MOCK_MODE=false \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Physical phone on same Wi-Fi:

```bash
cd mobile
flutter run \
  --dart-define=MOCK_MODE=false \
  --dart-define=API_BASE_URL=http://YOUR_MAC_LAN_IP:8000
```

Find your Mac LAN IP:

```bash
ipconfig getifaddr en0
```

Make sure `DJANGO_ALLOWED_HOSTS` and CORS settings in `.env` include that IP.

## Connected Core Flows

With `MOCK_MODE=false`, the mobile app uses backend endpoints for:

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
cd mobile
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
