# NutriNova AI Senior Review Bug List

Last reviewed: 2026-06-29

## Critical

- No critical cross-user data leak was found in the reviewed core flows. Backend querysets for foods, meals, habits, profiles, and photo analyses are user-scoped or use `visible_foods_for_user`.

## High Priority Fixed In This Pass

- Flutter dashboard meal data was still static/empty even after users logged food. Fixed by loading `/api/meals/?date=YYYY-MM-DD` and feeding real meal items into the dashboard.
- Flutter meal log screen used hardcoded meals. Replaced with real backend meal logs, empty/loading/error states, and source/confidence badges.
- Food search did not lead to a real food detail/manual logging flow. Added a connected food detail screen with quantity/unit/grams controls and save-to-meal.
- Custom food creation sent blank optional nutrient fields as empty strings, causing decimal validation failures. Fixed by omitting blank optional fields.
- Habit checkboxes on dashboard and checklist screens did not reliably refresh backend state. Added check/uncheck calls and invalidation for dashboard, today habits, and month grid.
- Habit month grid was a static placeholder. Connected it to `/api/habits/month-grid/`.
- Photo meal confirmation refreshed the dashboard but not the meal log. Fixed by invalidating today’s meal logs after confirmation.
- Meal list queryset could cause extra source lookups per meal item. Fixed prefetch/select-related paths for food source metadata.
- Dashboard weight trend used placeholder data. Fixed with user-scoped `/api/body-metrics/` and `/api/body-metrics/trend/`, plus mobile weight logging.

## Medium Priority Remaining

- Advanced smart insight cards still use lightweight local logic until deeper coach insight endpoints are connected to the mobile dashboard.
- Barcode scan UI exists, but the full phone-camera-to-food-detail loop should be tested on a real device once camera permissions are available.
- Recipe builder and analytics screens are present but are not as deeply connected as the core daily logging loop.
- Mobile tests cover auth, widgets, API client, and photo review parsing; additional widget tests should cover food detail save, meal log rendering, and habit check/uncheck.
- Backend importers are sample-friendly, but production USDA/Open Food Facts bulk imports need real dataset dry runs before launch.

## Notes

- AI photo nutrition remains an estimate and continues to require review/confirmation before meal logging.
- Private custom foods remain scoped with `created_by=user`; official foods remain globally visible.
