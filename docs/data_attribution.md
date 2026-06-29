# Data Attribution And Confidence Standards

NutriNova AI must keep nutrition provenance visible and auditable.

## Source Badges

Every food and nutrition response should show:

- `source_type`: USDA_FDC, OPEN_FOOD_FACTS, IFCT_2017, INDB, USER_CUSTOM, AI_ESTIMATE, MANUAL_ADMIN, or MANUAL_ADMIN_SAMPLE.
- `source` or `data_source`: human-readable source name.
- `confidence_score`: numeric confidence from 0 to 1.
- `verified`: whether the food is verified by a trusted source/admin process.
- `data_classification`: official_verified, official_unverified, user_custom, or ai_estimate.

## Source Meanings

- `USDA_FDC`: Primary generic nutrition source. Broad, public-domain food composition data.
- `OPEN_FOOD_FACTS`: Packaged/barcoded product source. Useful but community-maintained, so confidence should be visible.
- `IFCT_2017` and `INDB`: Indian food composition support. Verify license before distributing imported data.
- `USER_CUSTOM`: User-entered private foods. Not verified by NutriNova AI.
- `AI_ESTIMATE`: AI-estimated food or nutrition. Never treated as verified.
- `MANUAL_ADMIN` and `MANUAL_ADMIN_SAMPLE`: Admin-entered or local sample data.

## AI Estimates

AI estimates must remain pending until confirmed by the user. Low-confidence food matches or portion estimates should show review warnings.

## License Handling

Do not silently mix licenses. Imported foods and nutrient rows must retain source metadata, citation, license name, license URL, and external IDs where available.

## User Interface Rule

Mobile screens that show food search results, custom foods, meal logs, and photo results should display source/confidence badges whenever there is nutrition data on screen.
