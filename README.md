# NutriNova AI

NutriNova AI is a full-stack nutrition, fitness, meal logging, habit tracking, and AI-assisted food review app. It is built for real multi-user use with Django, PostgreSQL, Celery, Redis, MinIO/S3-compatible storage, JWT auth, OpenAPI docs, and Flutter.

Health disclaimer: NutriNova AI is for wellness tracking and education only. It is not intended to diagnose, treat, cure, or prevent any disease or medical condition.

## Stack

- Backend: Django 5, Django REST Framework, PostgreSQL, Celery, Redis
- Mobile: Flutter, Riverpod, Dio, go_router, secure token storage
- Storage: MinIO locally, S3-compatible abstraction for production
- API docs: drf-spectacular Swagger/OpenAPI
- Tests: pytest and Flutter tests
- CI: GitHub Actions for backend tests/lint and Flutter analyze/tests

## Local Setup On Kunal's Mac

Use the existing project folder. Do not create a new project or move files.

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit
```

First-time setup:

```bash
test -f .env || cp .env.example .env
docker compose build
docker compose up -d
docker compose ps
docker compose run --rm backend python manage.py migrate
docker compose run --rm backend python manage.py seed_core_nutrition
docker compose run --rm backend python manage.py import_usda_fdc_sample
docker compose run --rm backend python manage.py import_openfoodfacts_sample
docker compose run --rm backend python manage.py ensure_local_storage
```

Normal daily backend start:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit
docker compose up -d
docker compose ps
curl http://localhost:8000/api/health/
```

Open API docs:

```bash
open http://localhost:8000/api/docs/
```

Create an admin user when needed:

```bash
docker compose run --rm backend python manage.py createsuperuser
```

## Useful URLs

- API health: http://localhost:8000/api/health/
- Swagger docs: http://localhost:8000/api/docs/
- OpenAPI schema: http://localhost:8000/api/schema/
- Django admin: http://localhost:8000/admin/
- MinIO console: http://localhost:9001/

## Docker Commands

```bash
make up
make down
make backend-shell
make migrate
make ensure-local-storage
make test
make lint
make createsuperuser
```

Direct examples:

```bash
docker compose build
docker compose up -d
docker compose run --rm backend pytest
docker compose run --rm backend python manage.py migrate
```

## Mobile Setup

The current native-readiness evidence is in [docs/real_phone_qa.md](docs/real_phone_qa.md).
On 2026-10-07 this Mac has Flutter 3.44.3 / Dart 3.12.2, but no Android SDK,
full Xcode, CocoaPods, connected phone, or emulator. Tests and a web build are
not proof of native-phone operation. Follow the toolchain section in
[mobile/README.md](mobile/README.md) before using the native run commands.

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter pub get
dart format .
flutter analyze
flutter test
```

Run in mock mode without the backend:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter run --dart-define=MOCK_MODE=true
```

Run against the local backend on iOS simulator:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter devices
flutter run -d YOUR_IOS_SIMULATOR_ID --dart-define=API_BASE_URL=http://localhost:8000
```

Run against the local backend on Android emulator:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter devices
flutter run -d YOUR_ANDROID_EMULATOR_ID --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Run on a real iPhone or Android phone on the same Wi-Fi:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit
ipconfig getifaddr en0
```

If that command fails, use:

```bash
ifconfig en0
```

Look for the `inet` IPv4 address. Read it again whenever you change Wi-Fi;
an address from a previous laptop or hotspot may no longer work.

Add that IP to `DJANGO_ALLOWED_HOSTS` in `.env`, then reload container environment:

```bash
docker compose up -d --force-recreate backend celery_worker celery_beat
```

Then run Flutter with your Mac IP:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter devices
flutter run -d YOUR_PHONE_ID --dart-define=API_BASE_URL=http://YOUR_MAC_LAN_IP:8000
```

Replace `YOUR_PHONE_ID` with the ID from `flutter devices` and
`YOUR_MAC_LAN_IP` with the address reported above.

This Mac's Wi-Fi address on 2026-10-07 is `192.168.0.121`. It is now allowed in
the local `.env`; backend health and an existing MinIO photo both returned HTTP
200 through that address. Recheck the IP after changing networks. A current-phone
run, once the SDK and device are ready, is:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter pub get
flutter run -d YOUR_PHONE_ID --dart-define=API_BASE_URL=http://192.168.0.121:8000 --dart-define=MOCK_MODE=false
```

Check from the Mac, then from the phone's browser yourself:

```bash
curl --fail http://192.168.0.121:8000/api/health/
```

Phone-side reachability remains untested. Keep ports `8000` (API) and `9000`
(photo storage) reachable on the same Wi-Fi; guest-network isolation or a Mac
firewall rule may block them. Photo responses use the API request's host for
local MinIO URLs, so using the correct API host also fixes the preview host.

Backend and MinIO already bind to `0.0.0.0` through Docker Compose. The phone and Mac must be on the same Wi-Fi. Native iOS/Android builds do not need CORS, but Flutter web does.

API base URL quick map:

- iOS simulator: `http://localhost:8000`
- Android emulator: `http://10.0.2.2:8000`
- Real phone: `http://YOUR_MAC_LAN_IP:8000`
- Production later: your HTTPS API domain

Phone permission checklist:

- iPhone: allow Local Network, Camera, and Photos when requested. After denial,
  enable the relevant access for NutriNova AI in Settings and retry.
- Android: allow Camera when requested. Gallery may use the system photo picker
  without requesting full-library access; limited selected-photo access is enough.
  If denied, check Settings -> Apps -> NutriNova AI -> Permissions and retry.
- Barcode scan requires Camera.
- Meal photo scan works with Camera or Gallery. Gallery is the fastest smoke test.
- Real phones cannot use `localhost` for the Mac backend; use the Mac LAN IP.
- Voice recording/logging is not implemented, so no microphone permission is
  requested. Quick text add is available; it is not speech recognition.
- Android interrupted-photo recovery runs when Meal scan or Nutrition label is
  reopened; recovered photos are not uploaded or logged automatically.

Without `API_BASE_URL`, native Android defaults to `http://10.0.2.2:8000`;
iOS and web default to `http://localhost:8000`. Physical phones always need the
explicit Mac LAN URL. Scan results using `PHOTO_ANALYSIS_PROVIDER=mock` are
sample data, not image recognition. Real AI scanning needs the configured
provider and its API key; missing configuration no longer falls back to samples.

## Nutrition Import Commands

Core nutrients and sources:

```bash
docker compose run --rm backend python manage.py seed_core_nutrition
```

Small local samples:

```bash
docker compose run --rm backend python manage.py import_usda_fdc_sample
docker compose run --rm backend python manage.py import_openfoodfacts_sample
```

USDA FDC CSV downloads:

```bash
docker compose run --rm backend python manage.py import_usda_fdc --path /path/to/fdc_csv.zip --dataset foundation --mode starter --release-version 2026-04
docker compose run --rm backend python manage.py audit_food_database --apply
docker compose run --rm backend python manage.py food_database_stats
```

USDA FDC API:

```bash
USDA_FDC_API_KEY=your_key_here
docker compose run --rm backend python manage.py sync_usda_fdc_api --query "banana" --limit 5
```

Open Food Facts barcode lookup:

```bash
OPENFOODFACTS_USER_AGENT="NutriNovaAI/0.1 (your_email@example.com)"
docker compose run --rm backend python manage.py sync_openfoodfacts_barcode --barcode 8900000000011
```

For optional mobile-triggered lookup when a barcode is not already stored,
set both values in `.env`:

```bash
OPENFOODFACTS_USER_AGENT="NutriNovaAI/0.1 (your_email@example.com)"
OPENFOODFACTS_LIVE_LOOKUP=true
```

Reload the container environment after changing those settings:

```bash
docker compose up -d --force-recreate backend celery_worker celery_beat
```

Live lookup is off by default. It imports only the requested barcode, records an
import job, and never downloads a large database during app startup.

Indian foods CSV provided by project owner:

```bash
docker compose run --rm backend python manage.py import_indian_foods_csv --path /path/to/foods.csv --source IFCT_2017
```

## API Highlights

- Auth: `/api/auth/register/`, `/api/auth/login/`, `/api/auth/refresh/`, `/api/auth/logout/`
- Profile: `/api/me/`
- Food search: `GET /api/foods/search/?q=&source=&barcode=`
- Food detail: `GET /api/foods/{id}/`
- Custom food creation: `POST /api/foods/custom/`
- Manual meal logging: `POST /api/meals/manual-add/`
- Quick text add: `POST /api/meals/quick-add-text/`
- Confirm quick add: `POST /api/meals/quick-add-text/confirm/`
- Photo upload: `POST /api/photos/analyze-meal/`
- Photo review: `GET /api/photos/analyses/{id}/review/`
- Photo quantity correction: `POST /api/photos/detected-foods/{id}/increment/`
- Photo confirm as meal: `POST /api/photos/analyses/{id}/confirm-as-meal/`
- Habits today: `GET /api/habits/today/`
- Habit month grid: `GET /api/habits/month-grid/?month=YYYY-MM`
- Body metrics: `GET/POST /api/body-metrics/`
- Weight trend: `GET /api/body-metrics/trend/?days=30`

Every food/nutrition response should include source, confidence, verification, and classification metadata. See [docs/data_attribution.md](docs/data_attribution.md).

Custom-food estimates use a separate review and confirmation workflow. See
[docs/custom_food_estimation.md](docs/custom_food_estimation.md).

## Working MVP Daily Loop

After setup, a new developer can verify the core app loop with these steps:

1. Start Docker and prepare data:

```bash
test -f .env || cp .env.example .env
docker compose up -d
make migrate
docker compose run --rm backend python manage.py seed_core_nutrition
docker compose run --rm backend python manage.py import_usda_fdc_sample
docker compose run --rm backend python manage.py import_openfoodfacts_sample
make ensure-local-storage
```

2. Open Swagger at http://localhost:8000/api/docs/ or run the Flutter app with `MOCK_MODE=false`.
3. Register/login through the mobile app.
4. Complete onboarding and accept the wellness disclaimer.
5. Search foods from the dashboard or meal log.
6. Open a food detail page, choose quantity/unit/grams, and save to breakfast/lunch/dinner/snack.
7. Use quick add for text like `2 eggs` or `200g rice`, review the parsed result, and confirm.
8. Create a private custom food when search misses an item; it is marked `USER_CUSTOM` and scoped to the current user.
9. Scan or upload a meal photo, review detected foods, correct quantity with plus/minus, add missing food manually, and confirm as a meal.
10. Open the daily checklist, tick/untick habits, and confirm the month grid updates.
11. Log body weight from the dashboard weight trend card and confirm the chart uses backend data.

Senior review notes and remaining non-blocking gaps are tracked in [docs/senior_review_bug_list.md](docs/senior_review_bug_list.md).

## OpenAI Configuration Later

Local development uses the mock photo analysis provider by default.

To configure an OpenAI-backed provider later:

```bash
PHOTO_ANALYSIS_PROVIDER=openai
OPENAI_API_KEY=sk-...
```

Never expose API keys to Flutter. Only the backend should call AI providers.

## Production Readiness Notes

- Set `DJANGO_DEBUG=False`.
- Set a strong `DJANGO_SECRET_KEY`.
- Set production `DJANGO_ALLOWED_HOSTS`.
- Configure HTTPS and set:
  - `DJANGO_SECURE_SSL_REDIRECT=True`
  - `DJANGO_SESSION_COOKIE_SECURE=True`
  - `DJANGO_CSRF_COOKIE_SECURE=True`
  - `DJANGO_SECURE_HSTS_SECONDS=31536000`
- Configure `SENTRY_DSN` for error monitoring.
- Use real S3-compatible storage credentials.
- Run database backups. See [docs/database_backups.md](docs/database_backups.md).
- Review [docs/privacy_policy_draft.md](docs/privacy_policy_draft.md) before launch.
- Show [docs/health_disclaimer.md](docs/health_disclaimer.md) in onboarding and settings.

## Common macOS Issues

- Docker not running: open Docker Desktop before `make up`.
- Port already used: stop the process using ports `8000`, `5432`, `6379`, `9000`, or `9001`.
- Flutter cannot see iOS simulator: run `flutter doctor` and open Xcode once.
- Android emulator cannot reach backend: use `http://10.0.2.2:8000`.
- Physical phone cannot reach backend: use your Mac LAN IP, keep both devices on the same Wi-Fi, add the IP to `DJANGO_ALLOWED_HOSTS`, and restart the backend.
- Photo preview image does not load: run `make ensure-local-storage` and confirm port `9000` is reachable from the simulator or phone.
- MinIO credentials fail: confirm `.env` values match the MinIO service environment.

## Verification

```bash
make test
make lint
cd mobile
flutter analyze
flutter test
```
