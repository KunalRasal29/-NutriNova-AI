from django.core.management.base import BaseCommand

from foods.importers import (
    create_import_job,
    finish_import_job,
    get_data_source,
    get_fixture_path,
    import_json_food_records,
    load_json_fixture,
    seed_core_reference_data,
)
from foods.models import Food
from nutrition.models import NutritionDataSource


class Command(BaseCommand):
    help = "Import a small local Open Food Facts packaged-food fixture."

    def handle(self, *args, **options):
        seed_core_reference_data()
        source = get_data_source(NutritionDataSource.SourceType.OPEN_FOOD_FACTS)
        fixture_path = get_fixture_path("openfoodfacts_sample_products.json")
        job = create_import_job(source, file_name=str(fixture_path))

        records = load_json_fixture(fixture_path)
        result = import_json_food_records(
            records,
            source,
            default_food_type=Food.FoodType.BRANDED,
        )
        finish_import_job(job, result)

        self.stdout.write(
            self.style.SUCCESS(
                "Imported Open Food Facts sample: "
                f"{result.rows_created} created, {result.rows_updated} updated, "
                f"{len(result.errors or [])} errors."
            )
        )
