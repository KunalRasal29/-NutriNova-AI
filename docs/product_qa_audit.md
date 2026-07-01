# Product QA Audit

Date: 2026-07-01
Project path: `/Users/kunalrasal/Documents/LaPulgaFit`
Scope: Phase 11 full product QA audit and obvious P0/P1 fixes.

## Audit Method

- Inspected backend URL routing, serializers, models, services, seed/import commands, photo analysis provider, and test coverage.
- Inspected Flutter routes, repositories, API client, auth, dashboard, diary, food search, custom food, quick add, barcode, photo scan/review, checklist, progress, settings, and global add sheet.
- Verified backend health locally.
- Ran backend API smoke checks for register, onboarding profile update, food search, manual add, quick add parse, custom habit creation, today's habit grid, photo upload, and eager mock photo review.
- Did not open the browser, per instruction.

## Current Local Data Facts

- Foods in local database: 275
- Verified foods: 0
- Branded foods: 27
- Barcoded foods: 10
- User custom foods in local DB at audit time: 0
- Nutrition sources configured: USDA FoodData Central, IFCT 2017, Indian Nutrient Databank, Open Food Facts, Manual Admin Sample, User Custom, AI Estimate.
- Photo analysis provider default: `mock`

## What Works

### Register, Login, Logout

- Register and login are real backend flows through `/api/auth/register/` and `/api/auth/login/`.
- JWT access/refresh storage is wired with secure storage.
- Logout clears local tokens even if backend refresh-token blacklist fails.
- Auth redirects protect app routes.

### Onboarding

- Onboarding writes profile fields through `/api/me/`.
- Backend serializer accepts current fields: display name, height, weight, activity level, goal type, dietary preference, and onboarding completion.
- Health disclaimer acceptance is required before continuing.

### Dashboard

- Dashboard loads backend daily nutrition summary, today's meals, habits, and weight trend.
- Calories, macros, fiber, sugar, sodium, and available micronutrients are shown.
- Empty meals/checklist/weight states are understandable.
- Quick actions route to food logging, quick add, barcode, and photo scan.

### Diary

- Diary groups Breakfast, Lunch, Dinner, and Snacks.
- Meal sections show calories and macro totals.
- Logged foods show grams, calories, protein, carbs, and fat.
- Edit and delete actions call backend item update/delete endpoints and refresh dashboard/diary.

### Food Search and Add Food

- Search is API-backed through `/api/foods/search/`.
- Recent, frequent, favorites, and my foods are backend-backed.
- One-tap add works from result cards.
- Food detail supports serving choice, exact grams, nutrition label, and save-to-meal.
- Custom food creation is backend-backed and redirects to the new food detail screen.

### Quick Add

- Text quick add is API-backed through `/api/meals/quick-add-text/`.
- Review/edit before confirm is present.
- Confirming quick add saves meal items and refreshes diary/dashboard.

### Barcode

- Camera barcode scanning is wired with `mobile_scanner`.
- Manual barcode entry is available.
- Known seeded barcodes can be looked up.
- Unknown barcodes offer a custom-food fallback.

### Photo Meal Scan

- Photo picker supports camera and gallery.
- Upload/review/confirm endpoints are wired.
- Review screen supports quantity changes, unit changes, grams correction, remove/restore, add missing food, and confirm-as-meal.
- Dashboard and diary refresh after confirm.

### Checklist / Habits

- Custom checklist item creation is backend-backed.
- Template habits are backend-backed.
- Today check/uncheck calls backend and refreshes dashboard/progress.
- Month grid is backend-backed.

### Progress / Analytics

- Weekly calories trend, protein trend, macro split, habit completion, weight trend, and insights are present.
- Empty states guide the user instead of looking broken.

### Settings

- Settings rows open useful detail sheets instead of dead rows.
- Account sheet includes sign out.
- API base URL and mock mode status are visible.

## Phase 11 Smoke Test Results

- `docker compose ps`: backend, Postgres, Redis, MinIO, Celery worker, and Celery beat were running.
- `GET /api/health/`: passed with database `ok`.
- API smoke pass:
  - register: `201`
  - onboarding profile update: `200`
  - food search for `chicken breast`: `200`, 25 results
  - manual add: `201`
  - quick add parse for `2 eggs`: `200`
  - habit create: `201`
  - today's habits: `200`
- Photo smoke pass:
  - upload valid PNG: `201`
  - eager mock analysis review: `200`, 1 detected item
- Browser/UI was not opened.

## Fixed During This Phase 11 Pass

### P1: Onboarding Failure Could Bounce User Back To Login

Problem:
If profile setup failed after registration, the auth controller could replace the signed-in user state with an error. Because routing treats no current user as logged out, that could send the user away from onboarding instead of showing a clear setup error.

Fix:
Onboarding now keeps the signed-in user state during profile-save errors, shows a local error banner, and keeps the user on the setup screen. A regression test covers this.

Files:
- `mobile/lib/src/features/auth/auth_controller.dart`
- `mobile/lib/src/features/onboarding/onboarding_screen.dart`
- `mobile/test/auth_controller_test.dart`

### P2: Photo Scan Copy Over-Promised AI Accuracy

Problem:
The screen title said `AI meal scan`, but the local provider is mock by default and real AI photo transport is not enabled.

Fix:
Changed the screen title to `Meal photo review` so the UI still supports the flow without implying production AI accuracy.

File:
- `mobile/lib/src/features/photos/photo_scan_screen.dart`

### P2: Nutrition Target Settings Copy Was Too Strong

Problem:
Settings said targets are calculated from the profile, but target generation is still not fully personalized.

Fix:
Changed the settings sheet copy to say targets use local defaults and profile data where available.

File:
- `mobile/lib/src/features/profile/profile_settings_screen.dart`

## Previously Verified Fixes Already Present

- Photo upload uses `XFile.readAsBytes()` and byte-based multipart upload, avoiding fragile path-only upload behavior.
- The global add sheet has a real Log Weight route.
- The dashboard notification button opens an explanatory sheet instead of doing nothing.

## Priority Issues

### P0 Blocks App Use

No confirmed P0 blockers found during code/API audit.

Residual risk:
- Real iPhone/Android camera and barcode behavior still needs physical-device QA.
- A changed Mac Wi-Fi IP can still break real-phone API access until `.env` and the Flutter `API_BASE_URL` are updated.
- Full UI interaction smoothness still needs physical-phone testing; this audit used code review and backend smoke tests, not browser automation or a device session.

### P1 Blocks Demo Quality

1. Photo "AI" accuracy is not production-grade.
   - Backend defaults to `PHOTO_ANALYSIS_PROVIDER=mock`.
   - OpenAI provider exists but intentionally raises an error because transport/prompt/network policy are not configured.
   - This means camera/photo review is useful as a flow demo, not as accurate AI nutrition.

2. Food database is far too small for a serious nutrition app.
   - Current local DB has 275 foods and only 10 barcoded products.
   - No foods are marked verified in the current local data.
   - Many packaged, restaurant, regional, and brand-specific foods will be missing.

3. Barcode coverage is very limited.
   - Scanner can scan, but lookup only succeeds if the barcode exists locally.
   - The app does not yet sync Open Food Facts live from the mobile flow.

4. Personalized nutrition targets are incomplete.
   - Dashboard defaults to 2000 kcal unless explicit goal records exist.
   - Onboarding profile data does not yet generate calorie/macro targets from age, height, weight, goal, activity, and sex.

5. Exercise is displayed in the calorie equation but not implemented.
   - Dashboard and diary show exercise as 0.
   - No exercise logging screen/API flow is wired in Flutter.

6. Reminders/notifications are not implemented.
   - Notification tap now responds, but reminder scheduling is still absent.

7. Data export is not implemented.
   - Settings honestly says export is not wired yet.

8. Async photo review can initially show `uploaded` with zero items.
   - The Flutter upload path polls review after upload, and the review screen has processing states.
   - Real-device timing still needs testing with Celery worker latency.

### P2 Hurts Smoothness Or Trust

1. Food search quality needs more ranking work.
   - Exact/alias/source ranking exists.
   - Typo tolerance is basic and depends on trigram matching.
   - Synonyms, Hindi/Indian spellings, brand aliases, and cooked/raw disambiguation need more coverage.

2. Macro accuracy depends heavily on source data.
   - Plain chicken breast having 0g carbs is correct.
   - But cooked/raw, oil, sauces, gravies, restaurant prep, and branded recipes can change calories/macros a lot.
   - The UI shows source/confidence, but the database needs stronger verification.

3. Serving unit vocabulary is inconsistent across flows.
   - Manual add uses units like `egg`, `bowl`, `tablespoon`.
   - Stored meal items use normalized units like `piece`, `serving`, `tbsp`.
   - This works technically, but can confuse users during edit/review.

4. Quick add still requires review.
   - Parser handles common examples, but complex natural language meals can still be wrong.
   - It should never be treated as fully automatic.

5. Custom food entry depends on user accuracy.
   - No nutrition label OCR.
   - No macro/calorie consistency warning.
   - No brand database lookup during creation.

6. Offline behavior is not production-grade.
   - No offline queue for logging.
   - No durable local cache strategy for diary/dashboard beyond in-memory provider state.

7. Loading and error states are better, but not fully polished everywhere.
   - Most major screens have loading/error states.
   - Some mutation buttons rely on snackbars instead of inline recovery.

8. Real-device network setup is still manual.
   - iOS simulator, Android emulator, and real phone URLs are documented.
   - The app cannot auto-discover the Mac backend IP.

9. Photo analysis deletion can race with async detected-food creation.
   - This surfaced during smoke-test cleanup when the worker created detected foods while cleanup was deleting the analysis.
   - It does not block current user flows, but admin/data-retention cleanup needs a safer task-aware approach.

### P3 Polish

1. App naming is still mixed between LaPulgaFit and NutriNova AI in repo/docs/history.
2. Settings contains a disabled Mock mode switch, which is informative but not editable.
3. Login/register screens are functional but not premium-level.
4. No forgot-password flow.
5. No app icon/launch-screen branding polish pass.
6. No accessibility audit yet.
7. Charts are useful but still basic compared with mature nutrition apps.

## Flow-by-Flow QA Notes

| Flow | Status | Notes |
| --- | --- | --- |
| Register | Works | Real backend flow. Needs stronger password UX later. |
| Login | Works | Real backend flow. Error messages are clean enough. |
| Onboarding | Works | Profile fields save, but targets are not fully personalized. |
| Dashboard | Works | Much cleaner; exercise/reminders still incomplete. |
| Diary | Works | Add/edit/delete are wired. Serving edit UX can improve. |
| Food search | Works | Backend-backed, but database size and ranking need major work. |
| Add food | Works | Detail screen and one-tap add work. Exact grams supported. |
| Edit/delete food | Works | Backend endpoints recompute daily summary. |
| Quick add | Works | Good for simple examples; must remain review-based. |
| Custom food | Works | User-entered accuracy only; no label OCR/validation. |
| Barcode | Partially works | Scanner and manual entry work; product coverage is small. |
| Photo meal scan | Flow works | Upload/review works; accuracy is not production-grade because provider is mock. |
| Checklist/habits | Works | Custom and template add work. Editing/archive/reminders missing. |
| Progress | Works | Useful with data; still basic versus premium apps. |
| Settings/profile | Works | Rows open sheets. Some features are informational only. |
| Logout/login again | Works | Token clear and auth redirects are wired. |

## What Feels Confusing

- Photo scanning can imply production AI accuracy unless the review/disclaimer is kept visible; current local provider is mock.
- Barcode scan can look broken when real products are missing from the small local database.
- Exercise is shown in calorie math but cannot be logged.
- Nutrition targets look authoritative but are not fully calculated from onboarding yet.
- Food source confidence exists but users may not understand when a value is official, estimated, custom, or low confidence.

## What Looks Unpolished

- Auth screens are functional but plain.
- Some screens still feel like feature panels rather than a deeply refined consumer app.
- Charts and reports are useful but not premium-level.
- Empty states are better than before, but some still need more direct next actions.

## Mock / Fake / Incomplete Areas

- Photo analysis provider is mock by default.
- OpenAI photo analysis transport is intentionally disabled.
- Voice logging is not implemented; the app correctly uses text quick add instead.
- Exercise logging is not implemented in Flutter.
- Reminder scheduling/notifications are not implemented.
- Export reports are not implemented.
- Live barcode sync from Open Food Facts is backend-command based, not mobile-flow based.
- Offline mode is not implemented.

## Real Phone Risks

- Real phones must use the Mac LAN IP, not `localhost`.
- Backend containers must be recreated after `.env` host changes, not only restarted.
- Android cleartext HTTP is allowed for local dev, but production must use HTTPS.
- iOS ATS is open for local dev; production needs tighter network policy.
- Camera/photo/barcode permissions are declared, but physical-device behavior still needs hands-on QA.
- Large images may upload slowly; compression/resize before upload is not implemented.

## Food And Macro Accuracy Risks

- 275 foods is not enough for daily real-world use.
- 10 barcoded products is far below production needs.
- No local foods are currently marked verified.
- Cooked/raw variants exist for some foods but not all.
- Indian foods need stronger regional variants and household serving conversions.
- Restaurant foods and packaged foods need much broader coverage.
- User custom foods can be inaccurate if the user enters bad label data.

## Camera / Photo Accuracy Risks

- Camera flow works as a review workflow, not as reliable automatic nutrition.
- Portion estimation is the hardest unresolved problem.
- Current provider can detect predictable mock cases, not arbitrary real meals.
- Users must correct grams, quantities, and food matches.
- Nutrition label OCR is not active in the Flutter UI.

## Updated Readiness

- Runnable MVP: 82%
- Demo-quality app: 72%
- Smooth premium nutrition app: 52%
- Food database quality: 45%
- Camera/AI meal accuracy: 22%
- Macro accuracy for seeded/common foods: 65%
- Macro accuracy across real-world foods: 40%

## Recommended Next Phase

Phase 12 should be Food Database System and Accuracy Foundation.

Priority goals:
- Mark trusted imported foods as verified where appropriate.
- Expand Indian, gym/bodybuilding, fruits, vegetables, dairy, snacks, beverages, restaurant, and branded foods.
- Add source-specific confidence rules.
- Improve cooked/raw variants and aliases.
- Add more barcode samples and a mobile-triggered Open Food Facts lookup path.
- Add tests for exact match, aliases, Indian spellings, barcode lookup, and serving conversions.
