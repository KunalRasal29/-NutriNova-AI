from decimal import Decimal

from django.core.management.base import BaseCommand

from nutrition.models import Nutrient, NutritionDataSource

# Public source references used for provenance docs and future importers:
# USDA FDC API: https://fdc.nal.usda.gov/api-guide/
# USDA FDC downloads: https://fdc.nal.usda.gov/download-datasets/
# Open Food Facts API: https://openfoodfacts.github.io/openfoodfacts-server/api/
# Indian Nutrient Databank: https://www.anuvaad.org.in/indian-nutrient-databank/


DATA_SOURCES = [
    {
        "name": "USDA FoodData Central",
        "source_type": NutritionDataSource.SourceType.USDA_FDC,
        "license_name": "CC0 1.0 Universal / public domain",
        "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "citation": (
            "U.S. Department of Agriculture, Agricultural Research Service. "
            "FoodData Central."
        ),
        "source_url": "https://fdc.nal.usda.gov/api-guide/",
        "update_frequency": "Periodic USDA releases",
        "reliability_score": Decimal("0.9500"),
        "is_active": True,
    },
    {
        "name": "Open Food Facts",
        "source_type": NutritionDataSource.SourceType.OPEN_FOOD_FACTS,
        "license_name": "Open Database License",
        "license_url": "https://opendatacommons.org/licenses/odbl/1-0/",
        "citation": "Open Food Facts contributors. Open Food Facts database.",
        "source_url": "https://openfoodfacts.github.io/openfoodfacts-server/api/",
        "update_frequency": "Community updated continuously",
        "reliability_score": Decimal("0.7500"),
        "is_active": True,
    },
    {
        "name": "IFCT 2017",
        "source_type": NutritionDataSource.SourceType.IFCT_2017,
        "license_name": "Permission required for electronic product use",
        "license_url": "https://www.nin.res.in/ebooks/IFCT2017_16122024.pdf",
        "citation": (
            "Longvah T, Ananthan R, Bhaskarachary K, Venkaiah K. "
            "Indian Food Composition Tables 2017, ICMR-NIN."
        ),
        "source_url": "https://www.nin.res.in/ebooks/IFCT2017_16122024.pdf",
        "update_frequency": "Reference release",
        "reliability_score": Decimal("0.9000"),
        "is_active": True,
    },
    {
        "name": "Indian Nutrient Databank",
        "source_type": NutritionDataSource.SourceType.INDB,
        "license_name": "Source-specific terms",
        "license_url": "",
        "citation": "Indian Nutrient Databank.",
        "source_url": "https://www.anuvaad.org.in/indian-nutrient-databank/",
        "update_frequency": "Source dependent",
        "reliability_score": Decimal("0.8500"),
        "is_active": True,
    },
    {
        "name": "User Custom",
        "source_type": NutritionDataSource.SourceType.USER_CUSTOM,
        "license_name": "User provided",
        "license_url": "",
        "citation": "User-entered foods created inside NutriNova AI.",
        "source_url": "",
        "update_frequency": "User managed",
        "reliability_score": Decimal("0.5000"),
        "is_active": True,
    },
    {
        "name": "AI Estimate",
        "source_type": NutritionDataSource.SourceType.AI_ESTIMATE,
        "license_name": "NutriNova AI generated estimate",
        "license_url": "",
        "citation": (
            "AI-assisted estimates require user confirmation and should be treated "
            "as approximate wellness data."
        ),
        "source_url": "",
        "update_frequency": "Generated on demand",
        "reliability_score": Decimal("0.3500"),
        "is_active": True,
    },
]

NUTRIENTS = [
    {
        "code": "calories",
        "name": "Calories",
        "unit": "kcal",
        "nutrient_group": Nutrient.NutrientGroup.MACRO,
        "recommended_daily_unit": "kcal",
        "aliases": ["energy", "kilocalories", "kcal"],
    },
    {
        "code": "protein_g",
        "name": "Protein",
        "unit": "g",
        "nutrient_group": Nutrient.NutrientGroup.MACRO,
        "recommended_daily_unit": "g",
        "aliases": ["protein"],
    },
    {
        "code": "carbs_g",
        "name": "Carbohydrates",
        "unit": "g",
        "nutrient_group": Nutrient.NutrientGroup.MACRO,
        "recommended_daily_unit": "g",
        "aliases": ["carbs", "carbohydrate", "total carbohydrate"],
    },
    {
        "code": "fat_g",
        "name": "Total Fat",
        "unit": "g",
        "nutrient_group": Nutrient.NutrientGroup.MACRO,
        "recommended_daily_unit": "g",
        "aliases": ["fat", "total lipid"],
    },
    {
        "code": "fiber_g",
        "name": "Dietary Fiber",
        "unit": "g",
        "nutrient_group": Nutrient.NutrientGroup.MACRO,
        "recommended_daily_unit": "g",
        "aliases": ["fiber", "fibre"],
    },
    {
        "code": "sugar_g",
        "name": "Sugar",
        "unit": "g",
        "nutrient_group": Nutrient.NutrientGroup.MACRO,
        "recommended_daily_unit": "g",
        "aliases": ["sugars", "total sugars"],
    },
    {
        "code": "added_sugar_g",
        "name": "Added Sugar",
        "unit": "g",
        "nutrient_group": Nutrient.NutrientGroup.MACRO,
        "recommended_daily_unit": "g",
        "aliases": ["added sugars", "free sugar"],
    },
    {
        "code": "net_carbs_g",
        "name": "Net Carbohydrates",
        "unit": "g",
        "nutrient_group": Nutrient.NutrientGroup.MACRO,
        "recommended_daily_unit": "g",
        "aliases": ["net carbs", "available carbohydrate"],
    },
    {
        "code": "energy_kj",
        "name": "Energy",
        "unit": "kJ",
        "nutrient_group": Nutrient.NutrientGroup.MACRO,
        "recommended_daily_unit": "kJ",
        "aliases": ["kilojoules", "energy kj"],
    },
    {
        "code": "sodium_mg",
        "name": "Sodium",
        "unit": "mg",
        "nutrient_group": Nutrient.NutrientGroup.MINERAL,
        "recommended_daily_unit": "mg",
        "aliases": ["salt", "na"],
    },
    {
        "code": "potassium_mg",
        "name": "Potassium",
        "unit": "mg",
        "nutrient_group": Nutrient.NutrientGroup.MINERAL,
        "recommended_daily_unit": "mg",
        "aliases": ["k"],
    },
    {
        "code": "calcium_mg",
        "name": "Calcium",
        "unit": "mg",
        "nutrient_group": Nutrient.NutrientGroup.MINERAL,
        "recommended_daily_unit": "mg",
        "aliases": ["ca"],
    },
    {
        "code": "iron_mg",
        "name": "Iron",
        "unit": "mg",
        "nutrient_group": Nutrient.NutrientGroup.MINERAL,
        "recommended_daily_unit": "mg",
        "aliases": ["fe"],
    },
    {
        "code": "vitamin_a_mcg",
        "name": "Vitamin A",
        "unit": "mcg",
        "nutrient_group": Nutrient.NutrientGroup.VITAMIN,
        "recommended_daily_unit": "mcg",
        "aliases": ["retinol activity equivalents", "rae"],
    },
    {
        "code": "vitamin_c_mg",
        "name": "Vitamin C",
        "unit": "mg",
        "nutrient_group": Nutrient.NutrientGroup.VITAMIN,
        "recommended_daily_unit": "mg",
        "aliases": ["ascorbic acid"],
    },
    {
        "code": "vitamin_d_mcg",
        "name": "Vitamin D",
        "unit": "mcg",
        "nutrient_group": Nutrient.NutrientGroup.VITAMIN,
        "recommended_daily_unit": "mcg",
        "aliases": ["calciferol"],
    },
    {
        "code": "folate_mcg",
        "name": "Folate, Total",
        "unit": "mcg",
        "nutrient_group": Nutrient.NutrientGroup.VITAMIN,
        "recommended_daily_unit": "mcg",
        "aliases": ["total folate", "food folate"],
    },
    {
        "code": "folic_acid_mcg",
        "name": "Folic Acid",
        "unit": "mcg",
        "nutrient_group": Nutrient.NutrientGroup.VITAMIN,
        "recommended_daily_unit": "mcg",
        "aliases": ["synthetic folate", "pteroylmonoglutamic acid"],
    },
    {
        "code": "cholesterol_mg",
        "name": "Cholesterol",
        "unit": "mg",
        "nutrient_group": Nutrient.NutrientGroup.OTHER,
        "recommended_daily_unit": "mg",
        "aliases": ["cholesterol"],
    },
    {
        "code": "saturated_fat_g",
        "name": "Saturated Fat",
        "unit": "g",
        "nutrient_group": Nutrient.NutrientGroup.FATTY_ACID,
        "recommended_daily_unit": "g",
        "aliases": ["saturates", "saturated fatty acids"],
    },
    {
        "code": "trans_fat_g",
        "name": "Trans Fat",
        "unit": "g",
        "nutrient_group": Nutrient.NutrientGroup.FATTY_ACID,
        "recommended_daily_unit": "g",
        "aliases": ["trans fatty acids"],
    },
]


class Command(BaseCommand):
    help = "Seed core NutriNova AI nutrition data sources and nutrients."

    def handle(self, *args, **options):
        sources_created = 0
        sources_updated = 0
        nutrients_created = 0
        nutrients_updated = 0

        for source in DATA_SOURCES:
            _, created = NutritionDataSource.objects.update_or_create(
                name=source["name"],
                defaults=source,
            )
            sources_created += int(created)
            sources_updated += int(not created)

        for nutrient in NUTRIENTS:
            _, created = Nutrient.objects.update_or_create(
                code=nutrient["code"],
                defaults=nutrient,
            )
            nutrients_created += int(created)
            nutrients_updated += int(not created)

        self.stdout.write(
            self.style.SUCCESS(
                "Seeded nutrition core: "
                f"{sources_created} sources created, {sources_updated} updated; "
                f"{nutrients_created} nutrients created, {nutrients_updated} updated."
            )
        )
