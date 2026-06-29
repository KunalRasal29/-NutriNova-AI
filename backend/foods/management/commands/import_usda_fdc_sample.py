from django.core.management.base import BaseCommand

from foods.importers import (
    create_import_job,
    finish_import_job,
    get_fixture_path,
    get_manual_sample_source,
    import_json_food_records,
    load_json_fixture,
    seed_core_reference_data,
)
from foods.models import Food


class Command(BaseCommand):
    help = "Import a small local USDA-style sample fixture for fast development."

    def handle(self, *args, **options):
        seed_core_reference_data()
        source = get_manual_sample_source()
        fixture_path = get_fixture_path("usda_fdc_sample_foods.json")
        job = create_import_job(source, file_name=str(fixture_path))

        records = load_json_fixture(fixture_path)
        result = import_json_food_records(
            records,
            source,
            default_food_type=Food.FoodType.GENERIC,
        )
        finish_import_job(job, result)

        self.stdout.write(
            self.style.SUCCESS(
                "Imported USDA FDC sample: "
                f"{result.rows_created} created, {result.rows_updated} updated, "
                f"{len(result.errors or [])} errors."
            )
        )
