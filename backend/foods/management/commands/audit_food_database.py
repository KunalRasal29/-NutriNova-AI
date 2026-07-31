from django.core.management.base import BaseCommand

from foods.models import Food
from foods.services.data_quality import (
    apply_food_quality_assessment,
    assess_food_quality,
)


class Command(BaseCommand):
    help = "Audit food nutrition and serving quality; optionally persist scores."

    def add_arguments(self, parser):
        parser.add_argument(
            "--apply",
            action="store_true",
            help="Persist completeness, quality scores, and warnings.",
        )
        parser.add_argument("--limit", type=int, default=0)

    def handle(self, *args, **options):
        queryset = Food.objects.select_related("source").prefetch_related(
            "nutrients__nutrient",
            "servings",
        )
        if options["limit"]:
            queryset = queryset[: options["limit"]]

        audited = 0
        warned = 0
        warning_counts: dict[str, int] = {}
        for food in queryset.iterator(chunk_size=500):
            assessment = (
                apply_food_quality_assessment(food)
                if options["apply"]
                else assess_food_quality(food)
            )
            audited += 1
            if assessment.warnings:
                warned += 1
            for warning in assessment.warnings:
                key = warning.split(":", 1)[0]
                warning_counts[key] = warning_counts.get(key, 0) + 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Audited {audited} foods; {warned} have warnings; "
                f"persisted={options['apply']}."
            )
        )
        for warning, count in sorted(warning_counts.items()):
            self.stdout.write(f"  {warning}: {count}")
