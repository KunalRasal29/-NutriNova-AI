# Next Steps: Standalone Prompts

Send these one at a time, in order. Each block is a complete prompt.
Review the results and remaining issues before sending the next one.
These prompts are instructions for future work, not a claim that it is finished.

## Prompt 1: Checkpoint The Current Fixes

```text
Continue the existing LaPulgaFit / NutriNova AI project at:
/Users/kunalrasal/Documents/LaPulgaFit
Do not create a new project or folder. Preserve unrelated changes.
Everything stays free and open: no paywalls, subscriptions, trials, or feature locks.
This is for me and my friends. Do not expand into production launch, deployment,
app-store, enterprise security, compliance, or scaling work.
Do not open the browser/app unless I explicitly ask.

Goal: safely checkpoint the current stabilization work before further changes.

1. Read docs/stabilization_status.md and inspect git status, current branch,
   remote, staged files, unstaged changes, and untracked files.
2. Identify the stabilization code, tests, and documentation. Preserve all
   pre-existing user changes, including their staging state.
3. Do not commit transfer_backup/, lapulgafit_transfer_backup_2026-07-01.tar.gz,
   .env, database dumps, uploaded files, local credentials, or generated builds.
   Do not use git add . or git add -A. Stage only explicit intended files.
4. Run dart format ., flutter analyze, flutter test, backend tests, and
   docker compose ps. Do not claim a check passed unless you ran it.
5. Review the exact commit contents, make a scoped stabilization commit, and
   push to the existing GitHub remote. Do not force-push or rewrite history.
   Verify the remote branch contains the new commit. If authentication fails,
   preserve the local commit and explain the precise blocker.
6. Update the status documentation with the checkpoint information where useful.

At the end report the committed changes, test results, commit hash, push result,
and any work that remains local or unverified. Do not publish private backups.
```

## Prompt 2: Real-Phone QA And Native Reliability

```text
Continue the existing LaPulgaFit / NutriNova AI project at:
/Users/kunalrasal/Documents/LaPulgaFit
Do not create a new project or folder. Preserve unrelated changes and backups.
Everything stays free and open: no paywalls, subscriptions, trials, or feature locks.
This is for me and my friends; no production launch, deployment, app-store,
enterprise security, compliance, or scaling work.
Do not open a browser/app unless I explicitly ask. Ask before a device test
that requires opening it. Do not make paid API calls without my approval.

Goal: establish a genuinely working native app baseline on real phones.

1. Read docs/stabilization_status.md, inspect current source, Flutter devices,
   SDK/toolchain availability, API URL handling, and backend services.
2. Verify localhost for iOS simulator, 10.0.2.2 for Android emulator, and the
   current Mac LAN IP override for physical phones. Verify 0.0.0.0 binding,
   allowed hosts, same-Wi-Fi access, and reachable photo/storage URLs.
3. Verify native camera, gallery, barcode, storage, and microphone permission
   handling where those features exist. Permission denial must offer recovery.
4. Test registration, login, onboarding, dashboard, diary, search, one-tap add,
   exact-serving add, edit/delete, quick add, custom food, favorites, checklist,
   water, exercise, weight, progress, profile, and logout/login persistence.
5. Check background/resume, expired sessions, account switching, temporary
   network loss, double taps, keyboard/sheet layouts, and interrupted uploads.
6. Fix reproducible crashes, hangs, wrong saves, stale totals, and navigation
   failures. Add focused regression tests. Do not introduce a large redesign.
7. Create/update docs/real_phone_qa.md with separate Passed, Failed, and Not
   Tested evidence for each platform. If no phone is connected, prepare builds
   and instructions, continue independent checks, and mark hardware QA untested.
   Emulators, widget tests, and successful builds do not prove physical-phone QA.
8. Update README/mobile README with exact current commands and permission steps.
9. Run dart format ., flutter analyze, flutter test, backend tests, docker
   compose ps, and available native builds. Commit and push only intended files;
   exclude backups, .env, dumps, media, and build output. Never force-push.

Report devices/platforms actually tested, blockers fixed, results, build paths,
run commands/base URLs, commit hash, push status, and remaining phone checks.
```

## Prompt 3: Food Coverage And Nutrition Trust

```text
Continue the existing LaPulgaFit / NutriNova AI project at:
/Users/kunalrasal/Documents/LaPulgaFit
Do not create a new project or folder. Preserve unrelated changes and user logs.
Everything stays free and open: no paywalls, subscriptions, trials, or feature locks.
This is for me and my friends; no production launch, deployment, app-store,
enterprise security, compliance, or scaling work.
Do not open the browser/app unless I explicitly ask. Do not make paid API calls
without my approval.

Goal: make the food catalog and serving calculations substantially more trustworthy.

1. Inspect models, sources, importers, quality flags, search, servings, nutrient
   summaries, barcode data, and the current live catalog. Report real counts.
2. Audit verified/trusted claims against provenance. Manual sample records and
   AI estimates must not appear independently verified. Use clear source labels.
3. Validate raw versus cooked foods, edible weights, per-100g versus per-serving
   values, household conversions, and calorie/macro consistency. Investigate
   mismatches; do not force energy values to match a simplistic formula.
4. Expand coverage using credible attributable data through existing import
   patterns. Prioritize Indian household foods, gym foods, fruits, vegetables,
   dairy, snacks, drinks, and products we actually use. Record source identifiers.
   Variable recipes/restaurant portions should be labeled estimates or ranges.
5. Add useful aliases/spellings and sensible servings: egg, piece, roti/chapati,
   idli/dosa, cup, bowl, katori, slice, scoop, packet, serving, and plate where
   supported. Do not invent exact conversions for variable portions.
6. Preserve unknown nutrients as unknown. Show fiber, sugar, sodium, calcium,
   iron, potassium, and other supported nutrients when source data exists.
7. Improve exact/alias search ranking, deduplication, source-quality ranking,
   and exact barcode lookup. Clearly separate fixture barcodes from real labels.
8. Add tests for import idempotency, provenance, serving conversions, aliases,
   barcode matches, and totals for 500g raw/cooked chicken breast, 2 eggs,
   1 banana, 200g cooked rice, 2 chapati, and a defined scoop of whey.
9. Run the import locally without overwriting custom foods or historical logs.
   Record before/after coverage and missing-data counts in docs/food_quality.md.
10. Run backend tests, dart format ., flutter analyze, flutter test, and docker
    compose ps. Commit/push intended files only; exclude private backups, .env,
    dumps, uploaded media, and build output. Never force-push.

Report source-backed versus estimated counts, foods added/corrected, actual
macro examples with their basis, test results, manual searches, commit hash,
push status, and remaining gaps. Never claim every food or 100% accuracy.
```

## Prompt 4: Fast, Smooth Daily Logging

```text
Continue the existing LaPulgaFit / NutriNova AI project at:
/Users/kunalrasal/Documents/LaPulgaFit
Do not create a new project or folder. Preserve unrelated changes and user data.
Everything stays free and open: no paywalls, subscriptions, trials, or feature locks.
This is for me and my friends; no production launch, deployment, app-store,
enterprise security, compliance, or scaling work.
Do not open the browser/app unless I explicitly ask.

Goal: make everyday food logging fast, clear, and consistent across all entry points.

1. Inspect and test Diary, Search, Detail, Manual Add, Quick Add, Custom Food,
   Recent/Frequent/Favorites/My Foods, saved meals, and recipes.
2. Preserve selected date and Breakfast/Lunch/Dinner/Snacks through navigation,
   back actions, serving edits, quick add, custom-food creation, and saves.
3. Make result-card plus actions reliable with visible serving defaults, pending
   state, duplicate-tap protection, and clean success/error feedback.
4. Make exact-serving entry obvious: quantity, units, gram conversion, instant
   nutrient preview, and a clear save action. Reject invalid or unsupported units.
5. Make quick add reviewable and correctable, including uncertain matches and
   unmatched foods. Test eggs, banana, cooked rice, chapati, whey, and mixed entries.
6. Verify custom foods can be created, found, edited, and logged immediately.
   Verify favorites persist and all list tabs update after changes.
7. Make diary edit/delete dependable with confirmation or undo where appropriate.
   Improve repeat-last-meal/copy-to-date and saved meal/recipe workflows using
   existing patterns; do not add dead or placeholder controls.
8. After every write, verify Diary, Dashboard, Progress, and affected food lists
   agree. Show loading and retry states without hiding failures or freezing input.
9. Keep phone-first dark styling, compact desktop layouts, readable nutrient
   values, accessible controls, and keyboard-friendly forms. No big redesign.
10. Add UI and API regression coverage for the complete logging journeys,
    account/date isolation, failures, serving calculations, and summary refresh.
11. Run dart format ., flutter analyze, flutter test, backend tests, and docker
    compose ps. Commit/push intended files only; exclude backups, .env, dumps,
    uploaded media, and build output. Never force-push.

Report flows improved, actual behavior tested, remaining rough edges, test
results, commit hash, push status, and a short manual phone checklist.
```

## Prompt 5: Real Meal, Label, And Barcode Scanning

```text
Continue the existing LaPulgaFit / NutriNova AI project at:
/Users/kunalrasal/Documents/LaPulgaFit
Do not create a new project or folder. Preserve unrelated changes and user data.
Everything stays free and open: no paywalls, subscriptions, trials, or feature locks.
This is for me and my friends; no production launch, deployment, app-store,
enterprise security, compliance, or scaling work.
Do not open the browser/app unless I explicitly ask. Do not make paid API calls
or put keys in source code. Ask for approval before using a paid provider.

Goal: replace demo-only scanning with usable, honestly evaluated real scanning.

1. Inspect current providers, environment settings, Celery tasks, uploads, image
   access, barcode lookup, label parsing, and review/confirmation flows.
2. Identify a usable provider/configuration. If a key, approval, or account is
   missing, ask for the specific requirement and continue independent work.
   Never silently substitute mock detections or label a sample as real recognition.
3. Improve upload/analyze/retry/cancel/failure behavior and native permission
   recovery. Cover slow requests, interrupted uploads, and duplicate confirmation.
4. Meal review must support corrected food matches, quantity/grams, plus/minus,
   removal, missing-food search/manual entry, selected meal/date, and accurate
   totals from the corrected catalog data. Save only reviewed active items.
5. Label review must distinguish per-serving/per-100g bases and nutrient units,
   require confirmation of serving grams/core macros, preserve unknown fields,
   and allow corrections. Save a useful source-labeled food that can be logged.
6. Barcode capture/entry must handle exact matches, unknown products, optional
   live lookup configuration, network failure, and product-label verification.
7. Add automated tests using provider stubs and a small labeled evaluation set
   of representative meals/labels. Run real-provider evaluations only with my
   approval and available data. Separate detection, portion, and nutrient errors.
8. Record measured outcomes and limitations in docs/scan_quality.md. Do not
   present model confidence as proven accuracy or promise exact macros from photos.
9. Run backend tests, dart format ., flutter analyze, flutter test, docker
   compose ps, and available native builds. Commit/push intended files only;
   exclude keys, backups, dumps, private meal images, and build output.
   Never force-push.

Report what is real versus demo, configuration required, measured evaluation
results, hardware checks actually performed, tests, commit hash, push status,
and remaining limitations. Missing configuration is a blocker, not a passed test.
```

## Prompt 6: Voice Logging And Actual Reminders

```text
Continue the existing LaPulgaFit / NutriNova AI project at:
/Users/kunalrasal/Documents/LaPulgaFit
Do not create a new project or folder. Preserve unrelated changes and user data.
Everything stays free and open: no paywalls, subscriptions, trials, or feature locks.
This is for me and my friends; no production launch, deployment, app-store,
enterprise security, compliance, or scaling work.
Do not open the browser/app unless I explicitly ask. Do not make paid API calls
without my approval.

Goal: finish the currently incomplete voice and reminder features.

1. Inspect quick text add, habit/reminder preferences, platform permissions,
   existing dependencies, and supported Android/iOS/web capabilities.
2. Implement voice transcription using a maintained compatible platform
   integration where available. Feed editable transcription into the existing
   quick-add review flow; never save unreviewed recognized speech automatically.
3. Provide clear start/stop/listening/cancel states, locale handling, microphone
   permission recovery, and useful handling of silence or recognition errors.
   Unsupported web/devices must offer text entry, not a fake working microphone.
4. Implement real local notifications for supported reminders: meals, water,
   and habits where sensible. Support enable/disable, time editing, permissions,
   stable notification IDs, rescheduling, and cancellation without duplicates.
5. Respect local time/timezone changes, persist preferences, and separate
   accounts. On logout/disable/delete, cancel reminders that should no longer fire.
6. Test notifications after backgrounding and reopening. Check OS restrictions
   and document any real limitations rather than promising guaranteed delivery.
7. Add tests for transcription-to-review, parsing, notification scheduling
   decisions, preference persistence, cancellation, and permission-denied states.
8. Update README/mobile README with supported platforms and exact permission
   instructions. Record hardware-tested versus automated-only behavior.
9. Run dart format ., flutter analyze, flutter test, backend tests, docker
   compose ps, and available native builds. Commit/push intended files only;
   exclude backups, .env, dumps, media, and build output. Never force-push.

Report voice/reminder actions now implemented, platform limitations, actual
hardware checks, test results, commit hash, push status, and manual test steps.
Do not call notification delivery or microphone capture verified without testing it.
```

## Prompt 7: Useful Progress And Friends' Usability Pass

```text
Continue the existing LaPulgaFit / NutriNova AI project at:
/Users/kunalrasal/Documents/LaPulgaFit
Do not create a new project or folder. Preserve unrelated changes and user data.
Everything stays free and open: no paywalls, subscriptions, trials, or feature locks.
This is for me and my friends; no production launch, deployment, app-store,
enterprise security, compliance, or scaling work.
Do not open the browser/app unless I explicitly ask.

Goal: make the completed app coherent, useful, and pleasant in daily use.

1. Review the preceding QA reports, current implementation, and known gaps.
   Reproduce remaining issues before deciding on fixes.
2. Improve Progress with readable calorie/protein/weight trends, macro split,
   habit completion, and a weekly summary based on actual logged data.
   Unlogged days are missing data, not necessarily zero intake or failed habits.
3. Make date ranges, units, goals, empty states, and nutrient coverage clear.
   Insights must distinguish observed data from estimates and not imply medical
   certainty, invented progress, or complete adherence from partial logs.
4. Verify More/Profile rows, targets, units, settings, exports, and logout.
   Every visible control should have useful behavior and clear feedback.
5. Audit phone readability, tap targets, contrast, keyboard behavior, sheets,
   scrolling, back navigation, large text, loading, and errors. Improve measured
   slow paths without speculative scaling work or a wholesale redesign.
6. Prepare a one-week friends' test checklist in docs/friends_qa.md: realistic
   logging tasks, meals/barcodes to try, device details, reproduction steps,
   expected/actual results, and a short feedback template.
7. Fix issues from any supplied real feedback. If feedback or devices are not
   available, state that plainly; do not invent user testing or satisfaction.
8. Run the complete automated suites plus available builds and a regression
   matrix across logging, checklist, tracking, progress, scanning, and auth.
9. Update docs/stabilization_status.md with evidenced Passed/Failed/Not Tested
   status, remaining accuracy limitations, and exact manual follow-ups.
10. Run dart format ., flutter analyze, flutter test, backend tests, and docker
    compose ps. Commit/push intended files only; exclude backups, .env, dumps,
    uploaded media, and build output. Never force-push.

Report actual improvements, remaining issues ordered by impact, tests/builds,
commit hash, push status, and what friends should test next. Avoid invented
readiness percentages or claiming 100% food/camera accuracy.
```
