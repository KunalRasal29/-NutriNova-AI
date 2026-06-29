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

## Local Setup On macOS

1. Install Docker Desktop.
2. Install Flutter stable and Xcode or Android Studio if you want to run mobile.
3. Copy env values:

```bash
cp .env.example .env
```

4. Start services:

```bash
make up
```

5. In a second terminal, migrate and seed core data:

```bash
make migrate
docker compose run --rm backend python manage.py seed_core_nutrition
docker compose run --rm backend python manage.py import_usda_fdc_sample
docker compose run --rm backend python manage.py import_openfoodfacts_sample
```

6. Create an admin user:

```bash
make createsuperuser
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
make test
make lint
make createsuperuser
```

Direct examples:

```bash
docker compose build
docker compose up
docker compose run --rm backend pytest
docker compose run --rm backend python manage.py migrate
```

## Mobile Setup

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

Run in mock mode:

```bash
flutter run --dart-define=MOCK_MODE=true
```

Run against local backend on iOS simulator:

```bash
flutter run --dart-define=MOCK_MODE=false --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Run against local backend on Android emulator:

```bash
flutter run --dart-define=MOCK_MODE=false --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Run on a physical phone on the same Wi-Fi:

```bash
ipconfig getifaddr en0
flutter run --dart-define=MOCK_MODE=false --dart-define=API_BASE_URL=http://YOUR_MAC_LAN_IP:8000
```

For physical phone testing, add your Mac LAN IP to `DJANGO_ALLOWED_HOSTS` and add the matching origin to CORS settings in `.env`.

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
docker compose run --rm backend python manage.py import_usda_fdc_csv --path /path/to/fdc_csv.zip
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

## Working MVP Daily Loop

After setup, a new developer can verify the core app loop with these steps:

1. Start Docker and prepare data:

```bash
cp .env.example .env
make up
make migrate
docker compose run --rm backend python manage.py seed_core_nutrition
docker compose run --rm backend python manage.py import_usda_fdc_sample
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
- Physical phone cannot reach backend: use your Mac LAN IP and update allowed hosts/CORS.
- MinIO credentials fail: confirm `.env` values match the MinIO service environment.

## Verification

```bash
make test
make lint
cd mobile
flutter analyze
flutter test
```
