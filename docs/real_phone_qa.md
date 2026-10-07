# Real-Phone QA And Native Reliability

Checked on 2026-10-07 in `/Users/kunalrasal/Documents/LaPulgaFit`.
Starting commit: `79497436101e7e40d2b602356c4e8613071a73c8`, branch `main`.
Everything remains free. No browser/app, simulator, or phone app was opened.
No paid API calls were made. User database data and private backups were preserved.

## What Was Actually Tested

This pass uses source inspection, local HTTP requests, a separate backend test
database, and headless Flutter tests with repository/native-plugin test doubles.
**No physical phone or emulator was connected or tested.** A passing widget
test, emulator test, or build never counts as a physical-phone pass.

`flutter devices` lists only macOS desktop and Chrome, with no wireless devices.
Flutter 3.44.3 / Dart 3.12.2 are installed on macOS 15.5 arm64. Android SDK is
absent. `xcode-select -p` selects `/Library/Developer/CommandLineTools` and
`xcrun xcodebuild -version` fails because full Xcode is unavailable. CocoaPods
is also missing. Existing Android/iOS source folders were not regenerated.

## iPhone / iOS Evidence

### Passed (Configuration / Automation Only)

- iOS default URL is `http://localhost:8000` in the config test; explicit
  `API_BASE_URL` overrides are supported for a physical iPhone.
- `Info.plist` parses with `plutil -lint`. Camera/Photos descriptions exist;
  the Local Network description was added for the same-Wi-Fi Mac backend.
- Camera denial and gallery recovery paths pass headless widget tests with a
  fake image picker. This does not test iOS permission dialogs or real images.

### Failed / Blocked

- Attempted `flutter build ios --simulator --debug` with the localhost URL:
  exited 1 with `Application not configured for iOS`, before compilation.
  Native source files exist; full Xcode/toolchain availability is a confirmed
  blocker. Re-run after Xcode/CocoaPods setup to diagnose any further errors.
- No new `build/ios/iphonesimulator/Runner.app` was produced by this pass.

### Not Tested

Physical iPhone installation/signing, permission prompts and Settings recovery,
Local Network access from a phone, real camera/gallery/barcode hardware, secure
storage across termination/relaunch, resume, keyboard/safe-area behavior, and
all end-to-end journeys below. iOS simulator runtime QA was also not run.

## Android Evidence

### Passed (Configuration / Automation Only)

- Config test uses `http://10.0.2.2:8000` as the native Android emulator default.
- Main manifest includes Internet/Camera and version-scoped image permissions,
  local cleartext access, and keyboard resize support.
- Android automatic app backup is disabled to avoid restoring secure-storage
  ciphertext without its original encryption keys. Backend meals are unaffected.
- Interrupted-picker recovery is tested with fake Android lost-data responses;
  recovered images require explicit upload. Camera denial, cancellation, picker
  double taps, and retry after a failed upload pass headless tests.
- Barcode controller stops on background/route transitions, resumes on return,
  and waits for an unfinished native stop. Fake-plugin lifecycle and permission
  retry tests pass; these are not actual CameraX/device tests.

### Failed / Blocked

- Attempted `flutter build apk --debug` with the LAN URL: exited 1 with
  `No Android SDK found. Try setting the ANDROID_HOME environment variable.`
- No new `build/app/outputs/flutter-apk/app-debug.apk` was produced by this pass.
  Old APKs from another laptop do not verify this source checkpoint.

### Not Tested

USB/wireless phone installation, Android emulator runtime, camera/gallery/barcode
hardware, denied/limited permissions on actual Android versions, process death
and picker restoration, secure-storage reinstall behavior, battery/background
restrictions, network access from a phone, and all end-to-end journeys below.

## Local Network Evidence

- `ipconfig getifaddr en0`: **192.168.0.121** on this network/date. Recheck after
  moving networks. The earlier saved LAN address was outdated.
- Before the fix, the LAN health request returned HTTP 400 because this IP was
  absent from allowed hosts. Added it only to ignored local `.env`, preserving
  the existing hosts, then recreated backend/worker/beat without deleting volumes.
- After the fix, `http://192.168.0.121:8000/api/health/` returned HTTP 200,
  `status: ok`, database OK. An existing storage photo returned HTTP 200 and
  `image/png` through port 9000. These requests originated on the Mac, not a phone.
- Compose backend runs `runserver 0.0.0.0:8000`; API and MinIO publish on all
  interfaces. Postgres, Redis, MinIO, backend, Celery worker and beat are running;
  Postgres and Redis report healthy.
- New backend tests ensure local photo URLs use the request host for localhost,
  Android's emulator host, and the current LAN IP. External image URLs are unchanged.
- Same-Wi-Fi access, guest-network isolation, Mac firewall rules, and iOS Local
  Network permission must still be checked from each physical phone.

## Fixed During This Pass

- Permission-specific camera/gallery recovery messages and manual barcode fallback.
- Explicit barcode lifecycle ownership, camera retry, route pause/resume, and slow
  stop/start ordering. Manual barcode lookup/save cannot race another pending save.
- Concurrent picker/meal upload taps are guarded; Android scan screens retrieve
  interrupted picker data when reopened. No automatic upload or meal save occurs.
- Upload sends now have a 20-second timeout. Failed writes are not automatically
  replayed on network loss; expired-access-token retries still clone multipart data.
  Meal upload progress no longer pretends analysis started before sending the photo.
- Guards prevent rapid repeated saves in one-tap add, favorites, exact/manual add,
  quick add, photo confirm/manual correction, weight, and nutrition-target actions.
- Invalid/non-finite quantity, grams, weight, and goal fields cannot silently save
  substituted amounts. Portion inputs allow decimals. Unit dropdowns fit phone width.
- Dashboard checklist catches failed requests, prevents duplicate ticks, and refreshes
  habit/month/report data after success. Weight/goals refresh report summaries too.
- Calorie heading and quick-action grid overflows reproduced at phone width were fixed.
  The weight form remains scrollable with a simulated 320px keyboard inset.

## Flow Coverage Matrix

Automated evidence below is **not** a native end-to-end pass. "API" means the
backend suite on a separate test database; "UI" means headless test doubles.

| Flow | Automated / inspection evidence | iPhone | Android phone |
| --- | --- | --- | --- |
| Register | API journey; auth controller | Not Tested | Not Tested |
| Login | API JWT journey; client/token tests | Not Tested | Not Tested |
| Onboarding | API profile save; failed-save controller test | Not Tested | Not Tested |
| Dashboard | API summary; phone-width UI and checklist test | Not Tested | Not Tested |
| Diary | API saved meals; exercise-adjusted totals UI | Not Tested | Not Tested |
| Search | API search/alias/ranking; UI query/results | Not Tested | Not Tested |
| One-tap add | API logging; selected meal/default serving/rapid taps UI | Not Tested | Not Tested |
| Exact/manual serving | API conversions; decimal grams and invalid input UI | Not Tested | Not Tested |
| Edit/delete | API nutrition snapshots and summary changes; source inspection | Not Tested | Not Tested |
| Quick add | API parse/confirm; selected meal UI | Not Tested | Not Tested |
| Custom food | API create/add; wizard and navigation UI | Not Tested | Not Tested |
| Favorites | API toggle; cache and rapid-tap UI tests | Not Tested | Not Tested |
| Checklist/templates | API checks; create/check/uncheck/template/error UI | Not Tested | Not Tested |
| Water | API journey/summary; source inspection | Not Tested | Not Tested |
| Exercise | API tracking; Diary remaining calories UI | Not Tested | Not Tested |
| Weight | API metrics/trend; NaN/double-save/keyboard UI | Not Tested | Not Tested |
| Progress/reports | API reports; model/UI shell tests; refresh inspection | Not Tested | Not Tested |
| Profile/settings | API profile/goals/preferences; sheet/route inspection | Not Tested | Not Tested |
| Logout/login persistence | API journey; account-switch controller test | Not Tested | Not Tested |
| Barcode | Exact API lookup; fake native lifecycle/denial/retry | Not Tested | Not Tested |
| Photo/label | Mock API review/correction/failure; fake picker/upload UI | Not Tested | Not Tested |

## Interrupted / Adverse Conditions

| Scenario | Result actually demonstrated | Remaining hardware work |
| --- | --- | --- |
| Background/resume | Fake barcode start/stop and slow-stop tests pass | Real hardware, rapid app switches, all screens |
| Expired access/session | Refresh coalescing, revoked refresh, failed retry, multipart retry tests pass | Native storage/router behavior after sleep/relaunch |
| Account switching | Repository/cache isolation controller test passes | Switch during an in-flight write/upload |
| Network loss | Read retry, cached-food fallback, failed upload retry, checklist error UI pass | Wi-Fi drop mid-request and restoring service |
| Double taps | One-tap/favorite/weight/photo/serving regression tests pass | All buttons under native latency; backend write idempotency is not guaranteed |
| Keyboard/sheets | Phone-size checklist tests and keyboard-inset weight form pass | Actual keyboards, safe areas, large text, rotation, remaining forms/sheets |
| Interrupted picker | Fake Android recovery test passes; image waits for explicit upload | Kill/relaunch during camera/gallery and reopen original scan screen |
| Interrupted upload | Fake send timeout does not replay writes; upload UI can retry | Background/process death and ambiguous server acceptance |

Leaving a scan or terminating the process does not promise durable upload drafts
or automatic reconciliation. After an ambiguous timeout, check saved Diary data
before retrying a meal save. Voice recognition and device notification scheduling
remain unimplemented. Photo/label provider is currently `mock`; results are sample
data, not actual image recognition. Arbitrary real-world barcodes and exact photo
portion/macronutrient accuracy have not been established.

## Verification Results

| Command/check | Result |
| --- | --- |
| `dart format .` | 54 files checked/formatted |
| `flutter analyze` | No issues on the final rerun |
| `flutter test --reporter expanded` | 58 passed |
| `docker compose exec -T backend pytest -q` | 121 passed |
| Ruff on `tests/test_photo_analysis.py` | Passed |
| Django `manage.py check` | No issues |
| `docker compose ps` | All six services running |
| `plutil -lint ios/Runner/Info.plist` | Passed |
| Android debug build | Blocked: Android SDK missing |
| iOS simulator debug build | Blocked before compilation; full Xcode/CocoaPods unavailable |
| Standard JavaScript web release build | Passed; no browser opened |
| Physical phone / emulator | Not Tested |

The web output is `/Users/kunalrasal/Documents/LaPulgaFit/mobile/build/web`.
It is generated/ignored, not committed. Optional Wasm dry-run incompatibility in
the existing secure-storage dependency and a Cupertino font warning remain;
standard JavaScript compilation succeeds. Native icon rendering remains untested.

## Exact Run Instructions / Next Device Session

The commands, device prerequisites, current IP, permission recovery, and expected
build paths are in `README.md` and `mobile/README.md`. Base URLs:

- iOS simulator: `http://localhost:8000`.
- Android emulator: `http://10.0.2.2:8000`.
- Physical iPhone/Android on the current Wi-Fi: `http://192.168.0.121:8000`.

1. Install the missing SDK/toolchains and confirm the chosen phone in `flutter devices`.
2. Ask Kunal before running/opening the app for a device session.
3. Verify health from the phone, then every flow in the matrix with real-backend mode.
4. Deny Camera/Photos/Local Network, recover through Settings, and repeat.
5. Test backgrounding, force-close/relaunch, Wi-Fi loss, rapid taps, and keyboard layouts.
6. Record phone model, OS, date, source hash, observed result and reproducible steps.
   Do not mark physical-phone checks Passed based on builds or these tests.

Identify this checkpoint with `git log -1 --format='%H %s' -- docs/real_phone_qa.md`.
Private `.env`, transfer archives, database/media dumps, credentials, and build
outputs are excluded. The 41 previously staged private backup entries are left
unchanged; do not accidentally include them in a later blanket commit.
