from django.core.management.base import BaseCommand
from django.db.models import Count, Q

from foods.models import Food, FoodNutrient
from nutrition.models import Nutrient


class Command(BaseCommand):
    help = "Report food-catalog coverage, provenance, and quality statistics."

    def handle(self, *args, **options):
        core_codes = ("calories", "protein_g", "carbs_g", "fat_g")
        complete_macro_ids = (
            FoodNutrient.objects.filter(nutrient__code__in=core_codes)
            .values("food_id")
            .annotate(core_count=Count("nutrient_id", distinct=True))
            .filter(core_count=len(core_codes))
            .values("food_id")
        )
        source_rows = (
            Food.objects.values("source__name", "source__source_type")
            .annotate(count=Count("id"))
            .order_by("source__name")
        )

        self.stdout.write(f"foods_total: {Food.objects.count()}")
        self.stdout.write(f"nutrients_total: {Nutrient.objects.count()}")
        self.stdout.write(
            f"foods_with_complete_macros: "
            f"{Food.objects.filter(id__in=complete_macro_ids).count()}"
        )
        branded_count = Food.objects.filter(food_type=Food.FoodType.BRANDED).count()
        self.stdout.write(f"branded_foods: {branded_count}")
        self.stdout.write(f"barcoded_foods: {Food.objects.exclude(barcode='').count()}")
        self.stdout.write(
            f"deprecated_foods: {Food.objects.filter(is_deprecated=True).count()}"
        )
        low_quality_count = Food.objects.filter(
            Q(data_quality_score__lt=0.5) | ~Q(quality_warnings=[])
        ).count()
        self.stdout.write(f"low_quality_foods: {low_quality_count}")
        self.stdout.write("foods_by_source:")
        for row in source_rows:
            self.stdout.write(
                f"  {row['source__name']} ({row['source__source_type']}): "
                f"{row['count']}"
            )
