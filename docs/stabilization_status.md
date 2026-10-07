# Local Feature Stabilization

## Native Reliability Follow-Up (2026-10-07)

Prompt 2 continues from stabilization commit `79497436101e7e40d2b602356c4e8613071a73c8`.
See [real_phone_qa.md](real_phone_qa.md) for platform-specific Passed, Failed/Blocked,
and Not Tested evidence, the flow matrix, toolchain blockers, and next phone checks.

This pass fixes current-LAN access (ignored local `.env` only), adds the iOS
Local Network description, camera/gallery denial recovery, Android picker recovery,
barcode lifecycle/retry ordering, bounded upload sends, duplicate-save guards,
invalid-portion validation, and phone-width dashboard/serving-picker overflows.
Checklist, weight and target summary refreshes are tightened. Native hardware
accuracy and app smoothness are not claimed from automation.

The follow-up suite has 58 Flutter tests and 121 backend tests passing. A standard
web release build passes without opening the browser. Both native build attempts
are blocked: Android SDK is absent; full Xcode/CocoaPods are unavailable and the
iOS build exits before compilation. No new APK/iOS app was produced. No phone or
emulator was connected. No paid provider calls or new feature locks were added.

The Mac's current IP is `192.168.0.121`; Mac-side LAN health and existing photo
storage both returned HTTP 200. Recheck on a real phone and after Wi-Fi changes.
The previous staged private backup files retain their staging state and are
excluded from this scoped checkpoint.

The earlier checkpoint evidence below is retained as history, not new phone QA.

Checked on 2026-10-06 in `/Users/kunalrasal/Documents/LaPulgaFit`.
Source baseline: `2ac7f9f9875860eb6db876c63120b8c4a6dcf1ab` on `main`.
This report accompanies the scoped stabilization checkpoint on `main`.
All features remain free.
No app window or browser was opened for these checks.

## Checkpoint Verification

Checkpoint checks completed on 2026-10-07: `dart format .` checked 52 files with
no changes, `flutter analyze` reported no issues, all 41 Flutter tests passed,
and all 117 backend tests passed. `docker compose ps` showed all six services
running, with Postgres and Redis healthy. These checks reran for the checkpoint;
the web-build and additional checks below were performed during the preceding pass.

Remote: `https://github.com/KunalRasal29/-NutriNova-AI.git`, branch `main`.
The checkpoint contains only stabilization source, tests, README instructions,
this report, and the next-step prompts. Private transfer backups, `.env`, database
dumps, uploaded media, credentials, and generated builds are excluded.

To identify the commit containing this checkpoint without embedding its own hash:

```bash
git log -1 --format='%H %s' -- docs/stabilization_status.md
```

Physical-phone QA, real AI evaluation, food provenance auditing, voice logging,
and notification scheduling remain follow-up work, not completed checkpoint tasks.

## Fixed In This Pass

- Public login/register no longer inherit an old access token. Concurrent expired-token
  requests share one refresh. Failed retries complete instead of hanging, and a temporary
  refresh-server failure does not erase a valid saved session.
- Switching accounts recreates the nutrition repository so its food caches do not carry
  over. Favorite toggles and newly scanned labels clear affected cached food lists.
  Offline cached foods are no longer used to hide forbidden or deleted-food responses.
- Dashboard data requests run concurrently. Their errors retain the actual API message
  instead of exposing an internal parallel-request error.
- Logging, editing, deleting, tracking, and checklist actions invalidate nutrition/report
  views. Saved food also refreshes recent/frequent/usual lists in the main logging flows.
- Diary remaining calories include logged exercise. Barcode logging rejects invalid
  portion weights rather than quietly assuming 100 g. Habit/tracking reads use the
  phone's local date consistently with writes.
- Search ignores stale results while a newer query is being typed.
- Scan failure status survives transaction rollback; review screens poll while processing
  and show the failure instead of remaining stuck. Missing AI configuration fails visibly
  instead of silently returning sample detections.
- Demo scans explicitly identify sample results. Nutrition-label saving requires a real
  serving weight and all four core nutrition values; invalid, negative, and non-finite
  entries are rejected. Missing optional nutrients remain unknown rather than becoming zero.
- Phone checklist selectors, source badges, and nutrition summaries fit narrow layouts.
  Reminder preferences now clearly state that device notifications are not scheduled.
- Android emulator default is `http://10.0.2.2:8000`. iOS/web defaults stay localhost,
  and explicit `API_BASE_URL` overrides remain available for phones.
- README instructions preserve an existing `.env`, remove stale network addresses, and
  recreate containers when environment values change.

## Verification

| Check | Result |
| --- | --- |
| `dart format .` | 52 files checked; no remaining formatting changes |
| `flutter analyze` | No issues |
| `flutter test --reporter expanded` | 41 passed |
| Backend `pytest -q` | 117 passed |
| Ruff on changed backend Python files | Passed |
| Django system check | No issues |
| Migration dry run | No pending model changes |
| Standard Flutter JavaScript web build, real-backend mode | Passed |
| Backend health | HTTP 200; database OK |
| Swagger endpoint | HTTP 200 |
| Local web origin CORS | Allowed for `http://127.0.0.1:7357` |
| Docker Compose | Backend, worker, beat, Postgres, Redis, MinIO running |
| Physical phone / emulator QA | Not run; no phone or emulator connected |

The web build reports optional WebAssembly incompatibility in the existing secure-storage
dependency and a Cupertino font warning. The standard JavaScript build succeeds; Wasm
support and native icon rendering have not been validated in this pass.

The backend journey test uses a separate test database and real JWT/API endpoints for
registration, login, onboarding, search, favorites, barcode lookup, add/edit/delete,
quick add, custom foods, habits, water, exercise, weight, reports, and logout/login
persistence. It does not modify the user's saved meals.

Headless Flutter UI tests exercise custom checklist creation/check/uncheck, templates,
one-tap add with the selected meal and serving, custom-food navigation, quick-add review
and confirmation, exercise-adjusted diary totals, and scan polling. Their repository is
a test double; they are not a substitute for a real phone connected to the backend.

## Food And Scan Reality

The existing live database has 390 foods, 1,001 aliases, 941 serving records, and 30
barcoded entries. All 390 have core macros. There are 275 foods carrying a `verified`
flag, but that is a stored flag, not proof of independent nutrition verification.
Most records come from local/manual samples. This live database defines 16 nutrient
types; complete micronutrient coverage has not been audited. No bulk food import or
source-verification audit was performed here.

Current local scan settings use `PHOTO_ANALYSIS_PROVIDER=mock`, with no OpenAI key
configured. Meal and label scans therefore produce demo samples, not image recognition.
Real AI must be configured and evaluated on actual meals before accuracy can be claimed.
Even real image recognition needs portion correction; it cannot establish exact macros
from a photo alone. No paid app tier or user lock was added.

`OPENFOODFACTS_LIVE_LOOKUP` is off locally. Barcode lookup works for existing database
entries; arbitrary shop products are not guaranteed to resolve. Example barcodes in
fixtures are for testing, not evidence that the packaged products were verified.

## Still Needs Work

1. Connect a real Android/iPhone and test native camera, gallery, barcode capture,
   secure storage, permissions, and network/photo-preview access end to end.
2. Replace demo photo/label settings with a configured provider, then evaluate detections
   and portion corrections against a labeled meal set. Surface uncertain results honestly.
3. Expand food coverage from attributable sources and audit seed `verified` flags,
   raw/cooked distinctions, serving conversions, and missing micronutrients.
4. Voice recognition/logging is not implemented. Quick text add is available instead.
5. Reminder preferences are saved, but device notification scheduling is not implemented.
6. Live barcode imports need explicit configuration and testing with real product labels.
7. Tests cover important core paths, not every screen, interruption, or real-device scenario.
   Passing tests do not mean the whole app or nutrition data is 100% accurate.

## Next Manual Test

Use the exact setup instructions in `/Users/kunalrasal/Documents/LaPulgaFit/README.md`
and `/Users/kunalrasal/Documents/LaPulgaFit/mobile/README.md`.
The backend binds to `0.0.0.0:8000`. A physical phone needs the Mac's current LAN IP
in `API_BASE_URL`, and both devices must be on the same Wi-Fi.

1. Register, onboard, log out, and log back in; confirm saved profile and meals remain.
2. Add an egg to Dinner with the result-card plus button, then adjust its serving in
   Diary and delete it. Check Dashboard and Progress totals after each action.
3. Parse and confirm `2 eggs`, `1 banana`, `200g cooked rice`, `2 chapati`, and
   `1 scoop whey protein`; inspect matched foods and units before saving.
4. Favorite/unfavorite food, change tabs, and create a custom food. Verify My Foods
   and search show it and that it can be logged immediately.
5. Create a custom checklist item and a template, then check/uncheck them. Log water,
   exercise, and weight; reopen summary/report screens.
6. Scan a known database barcode; test an unknown product and permission denial.
   Test camera and gallery uploads, processing, review, corrections, and confirmation.
   Treat mock scan results as sample data throughout.
7. Repeat with a second account and temporary loss of Wi-Fi; look for stale data,
   incorrect success feedback, loading freezes, and unhelpful errors.

## Existing Backups

The 41 previously staged transfer-backup files were left unchanged. They include
private database/storage data and a secret-bearing archive. Do not use `git add .`
or include those backups in a later commit/push. No backup was deleted or moved.
