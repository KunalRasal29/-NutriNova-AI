# NutriNova AI Mobile

Flutter app for NutriNova AI on Android and iOS.

## 1. Install Flutter

Install Flutter stable from the official Flutter docs, then verify:

```bash
flutter doctor
```

Both native platform folders already exist. Do not regenerate the project to
work around a missing SDK. As checked on 2026-10-07, this Mac has Flutter 3.44.3
and Dart 3.12.2, but no Android SDK, full Xcode, or CocoaPods. Only macOS and
Chrome appear in `flutter devices`; no phone or emulator was found.

For Android, install the Android SDK and platform tools using Android Studio's
SDK Manager, then run `flutter doctor --android-licenses`. Enable USB debugging
on the phone and accept its computer authorization prompt.

For iOS, install full Xcode, complete its initial setup and simulator support,
select it as the active developer directory, and install CocoaPods for plugins
that require it. Once Xcode exists at the standard path:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
flutter doctor -v
flutter devices
```

These setup commands were not run here because full Xcode is not installed.
For an iPhone, trust this Mac, enable Developer Mode if requested, and select
your personal development team/signing in the existing Runner project when
Xcode requests it. Native builds remain blocked until the toolchains are ready.
See [Flutter's iOS setup](https://docs.flutter.dev/platform-integration/ios).

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
test -f .env || cp .env.example .env
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
flutter devices
flutter run -d YOUR_IOS_SIMULATOR_ID \
  --dart-define=API_BASE_URL=http://localhost:8000
```

Android emulator:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter devices
flutter run -d YOUR_ANDROID_EMULATOR_ID \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Physical phone on same Wi-Fi:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit
ipconfig getifaddr en0
```

If that fails on your Mac, run:

```bash
ifconfig en0
```

Use the `inet` IPv4 address. Check it again after changing networks or laptops;
do not reuse an old hotspot address.

Add that IP to `DJANGO_ALLOWED_HOSTS` in `.env`, reload the container environment, then run:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit
docker compose up -d --force-recreate backend celery_worker celery_beat
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter devices
flutter run -d YOUR_PHONE_ID \
  --dart-define=API_BASE_URL=http://YOUR_MAC_LAN_IP:8000
```

Replace the device ID and LAN IP placeholders with the current values.
On physical phones, test `http://YOUR_MAC_LAN_IP:8000/api/health/` first.
If you change the backend `.env` settings, use `docker compose up -d --force-recreate
backend celery_worker celery_beat`; a container restart does not reload its environment.

On 2026-10-07 the current LAN IP is `192.168.0.121`. The local `.env` includes
it in `DJANGO_ALLOWED_HOSTS`. For that network, after SDK setup and connection:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter pub get
flutter run -d YOUR_PHONE_ID \
  --dart-define=API_BASE_URL=http://192.168.0.121:8000 \
  --dart-define=MOCK_MODE=false
```

Do not reuse this IP after switching Wi-Fi without checking `ipconfig getifaddr en0`.
The Mac's LAN health and existing storage photo were reachable, but phone-side
Wi-Fi/firewall reachability has not been tested. The API binds to `0.0.0.0:8000`;
MinIO binds to `0.0.0.0:9000`. Both ports must be reachable from the phone.

### Build Without Opening The App

After installing the required native toolchains:

```bash
cd /Users/kunalrasal/Documents/LaPulgaFit/mobile
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.0.121:8000 --dart-define=MOCK_MODE=false
flutter build ios --simulator --debug --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=MOCK_MODE=false
```

Expected Android output after a successful build: `build/app/outputs/flutter-apk/app-debug.apk`.
Expected iOS simulator output after a successful build: `build/ios/iphonesimulator/Runner.app`.
Neither was generated in this QA pass. Android stopped with `No Android SDK found`;
iOS stopped with `Application not configured for iOS`. The native iOS sources
exist, but `xcode-select -p` selects CommandLineTools and `xcrun xcodebuild -version`
fails. Diagnose the iOS build again after installing full Xcode/CocoaPods.

Default API URLs are `localhost:8000` for iOS/web and `10.0.2.2:8000` for native
Android. Override `API_BASE_URL` for every physical-phone build. `MOCK_MODE=true`
is a non-persistent demo, not a way to test saved user data. A backend mock photo
provider also returns sample results, and is now labeled explicitly on review screens.

Backend and MinIO bind to `0.0.0.0` through Docker Compose. Your real phone and Mac must be on the same Wi-Fi, and phone photo previews also need port `9000` reachable for local MinIO images. Real phones cannot use `localhost` for the Mac backend.

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

- iOS: enable Local Network, Camera, and Photos for NutriNova AI in Settings
  when those permissions are requested. The app includes a local-network purpose
  description. If Local Network was denied, enable it before retrying API access.
- Android: Settings -> Apps -> NutriNova AI -> Permissions -> allow Camera.
  The system gallery picker can grant access only to selected images without a
  full-library permission. Do not expect a storage prompt on every Android version.
- Barcode scan needs Camera permission.
- Meal photo scan can use Camera or Gallery. Gallery is the fastest real-phone smoke test.
- Permission denial keeps manual barcode entry or Gallery available and shows
  a retry/recovery message. Barcode retries camera setup after permission changes.
- Barcode camera stops while backgrounded or while opening food details and
  restarts on return. Hardware behavior still needs phone verification.
- On Android, reopening a scan screen retrieves an image left by an interrupted
  native picker. Review it and upload explicitly; no meal is saved automatically.
- Microphone/voice logging and saving images back into the gallery are not
  implemented. No microphone prompt is expected; text add is the available flow.
- Android automatic app backup is disabled to avoid restoring secure-storage
  ciphertext without the matching device encryption keys. Meals remain on the backend.

Apple describes local-network permission recovery in
[its support guide](https://support.apple.com/en-us/102229).

### Common macOS Phone Testing Issues

- Phone cannot reach backend: use your Mac LAN IP instead of `localhost`.
- Backend rejects the phone request: add the LAN IP to `DJANGO_ALLOWED_HOSTS`, then recreate the backend/worker/beat containers as shown above.
- Photo preview image does not load: run `make ensure-local-storage` from the repo root and confirm port `9000` is reachable.
- Camera opens black: check simulator/device camera permissions and try a physical device for barcode scanning.
- Android emulator cannot connect: use `10.0.2.2`, not `127.0.0.1`.

### Real Phone MVP QA Checklist

Run this on the phone before demo:

1. Register a new account.
2. Login with the account.
3. Complete onboarding.
4. Open Dashboard and confirm it loads without red errors.
5. Open Diary and add food from search.
6. Edit and delete one logged food.
7. Use Text add with `2 eggs` and confirm it saves.
8. Open Barcode, try sample barcode `8900000000011`, and log it.
9. Open Meal scan, choose Gallery, upload a meal image, review, and confirm.
10. Add a checklist item, tick it, and confirm Dashboard/Progress refresh.
11. Open Progress and Settings.
12. Logout and login again.

Also test favorite/unfavorite, custom food creation and immediate logging,
water, exercise, weight, returning after backgrounding, permission denial,
temporary Wi-Fi loss, rapid double taps, and forms with the keyboard open.
Current scan settings produce demo samples, not real image recognition.
Record results separately for each phone in [../docs/real_phone_qa.md](../docs/real_phone_qa.md).

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
