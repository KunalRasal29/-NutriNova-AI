from decimal import Decimal

from django.core.management.base import BaseCommand
from django.db.models import Count

from foods.models import Food


def _macro_signature(food: Food) -> tuple[int | None, ...]:
    values = {item.nutrient.code: item.amount_per_100g for item in food.nutrients.all()}
    signature = []
    for code in ("calories", "protein_g", "carbs_g", "fat_g"):
        value = values.get(code)
        signature.append(None if value is None else int(value.quantize(Decimal("1"))))
    return tuple(signature)


class Command(BaseCommand):
    help = "Report likely food duplicates without modifying or merging records."

    def add_arguments(self, parser):
        parser.add_argument("--limit", type=int, default=100)
        parser.add_argument("--summary-only", action="store_true")

    def handle(self, *args, **options):
        group_queryset = (
            Food.objects.filter(is_deprecated=False)
            .exclude(normalized_name="")
            .values("normalized_name", "brand_name", "preparation_state")
            .annotate(candidate_count=Count("id"))
            .filter(candidate_count__gt=1)
            .order_by("-candidate_count")
        )
        if options["summary_only"]:
            self.stdout.write(
                self.style.SUCCESS(
                    f"duplicate_candidate_groups: {group_queryset.count()}"
                )
            )
            return
        groups = group_queryset[: options["limit"]]
        candidates = 0
        for group in groups:
            foods = list(
                Food.objects.filter(
                    normalized_name=group["normalized_name"],
                    brand_name=group["brand_name"],
                    preparation_state=group["preparation_state"],
                )
                .select_related("source")
                .prefetch_related("nutrients__nutrient")
                .order_by("-verified", "-data_quality_score")
            )
            signatures = {_macro_signature(food) for food in foods}
            confidence = "high" if len(signatures) == 1 else "review"
            candidates += 1
            self.stdout.write(
                f"[{confidence}] {group['normalized_name']} / "
                f"{group['preparation_state']}: {len(foods)} records"
            )
            for food in foods:
                self.stdout.write(
                    f"  {food.id} | {food.source.name} | {food.external_id or '-'} | "
                    f"macros={_macro_signature(food)}"
                )
        self.stdout.write(
            self.style.SUCCESS(f"duplicate_candidate_groups: {candidates}")
        )
