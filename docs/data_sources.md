# Data Sources

NutriNova AI keeps nutrition provenance attached to imported foods and every nutrient value. Importers are opt-in management commands; large public datasets are never downloaded during normal app startup.

## USDA FoodData Central

USDA FoodData Central is the preferred generic nutrition source. It provides an API and downloadable datasets:

- API guide: https://fdc.nal.usda.gov/api-guide/
- Downloads: https://fdc.nal.usda.gov/download-datasets/

USDA FoodData Central is published under CC0/public-domain terms. Keep the
USDA citation, release, dataset type, source identifier, original nutrient unit,
and normalized value on every imported record.

Recommended priority is Foundation Foods, FNDDS, SR Legacy, then Branded Foods.
Use the starter import for local development and full mode only when enough disk
space and time are available:

```powershell
docker compose run --rm backend python manage.py import_usda_fdc --path /data/fdc --dataset foundation --mode starter --release-version 2026-04
docker compose run --rm backend python manage.py import_usda_fdc --path /data/fdc --dataset fndds --mode full --release-version 2024-10
docker compose run --rm backend python manage.py import_usda_fdc --path /data/fdc --dataset branded --mode full --release-version 2026-04 --resume
```

Large files are streamed. Import jobs retain checksums, row progress, release
metadata, and errors. No large dataset is downloaded during application startup.

## Open Food Facts

Open Food Facts is useful for packaged and barcoded products:

- API docs: https://openfoodfacts.github.io/openfoodfacts-server/api/

It is volunteer-supplied data, so NutriNova AI stores it with lower confidence than verified lab or official data. Imported records should keep barcode, brand, ingredients, allergens, source metadata, and confidence scores.

Open Food Facts product responses are cached. Search-as-you-type always uses the
local PostgreSQL catalog; the mobile app does not send a remote Open Food Facts
search request for every keystroke.

Mobile barcode lookup checks the local catalog first. Optional live lookup is
enabled only with `OPENFOODFACTS_LIVE_LOOKUP=true` and a descriptive
`OPENFOODFACTS_USER_AGENT`. A live result is cached through the same
duplicate-safe importer and import-job audit trail. Missing fields remain empty
and lower the completeness/confidence warning instead of crashing the app.

## Preparation state

Foods can be marked as raw, cooked, prepared dishes, as sold/packaged, or not
specified. Importers infer a preparation state only when the food name makes it
clear. The app keeps "not specified" when it cannot make a reliable distinction
and asks the user to confirm the appropriate food or serving.

## IFCT / Indian Nutrient Databank

IFCT 2017 and the Indian Nutrient Databank can support Indian foods and recipes:

- Indian Nutrient Databank: https://www.anuvaad.org.in/indian-nutrient-databank/

IFCT 2017 restricts reproduction in an electronic product without prior ICMR-NIN
permission. Do not scrape or bulk-import the publication. Every Indian dataset
file must have its exact licence verified and must be explicitly confirmed:

```powershell
docker compose run --rm backend python manage.py import_indian_foods_csv --path /data/authorized.csv --source INDB --license-confirmed --release-version 2024
```

The flag records confirmation; it does not grant permission by itself.

## Catalog quality and duplicate review

```powershell
docker compose run --rm backend python manage.py audit_food_database --apply
docker compose run --rm backend python manage.py find_food_duplicates
docker compose run --rm backend python manage.py food_database_stats
```

Duplicate detection is read-only. Administrators can select a canonical
replacement and deprecate a duplicate without deleting it, so historical meals
continue to reference the original record.

## AI Estimates

AI photo estimates are never treated as verified nutrition. They should remain marked as estimates, require user confirmation, and must not overwrite sourced nutrition records.
