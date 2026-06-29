# Data Sources

NutriNova AI keeps nutrition provenance attached to imported foods and every nutrient value. Importers are opt-in management commands; large public datasets are never downloaded during normal app startup.

## USDA FoodData Central

USDA FoodData Central is the preferred generic nutrition source. It provides an API and downloadable datasets:

- API guide: https://fdc.nal.usda.gov/api-guide/
- Downloads: https://fdc.nal.usda.gov/download-datasets/

USDA data is generally suitable as a trusted base for generic foods. Keep the USDA source, citation, license fields, and `external_id` on every imported food and nutrient value. Confirm release-specific terms before redistributing bundled datasets.

## Open Food Facts

Open Food Facts is useful for packaged and barcoded products:

- API docs: https://openfoodfacts.github.io/openfoodfacts-server/api/

It is volunteer-supplied data, so NutriNova AI stores it with lower confidence than verified lab or official data. Imported records should keep barcode, brand, ingredients, allergens, source metadata, and confidence scores.

## IFCT / Indian Nutrient Databank

IFCT 2017 and Indian Nutrient Databank support Indian foods and common recipes:

- Indian Nutrient Databank: https://www.anuvaad.org.in/indian-nutrient-databank/

Only import files that the project owner provides and has permission to use. Do not scrape copyrighted PDFs. Verify license terms before distributing imported data.

## AI Estimates

AI photo estimates are never treated as verified nutrition. They should remain marked as estimates, require user confirmation, and must not overwrite sourced nutrition records.
