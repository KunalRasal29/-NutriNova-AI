from django.db import migrations, models

RAW_TERMS = (" raw", "raw ", "uncooked")
COOKED_TERMS = (
    "baked",
    "boiled",
    "cooked",
    "fried",
    "grilled",
    "roasted",
    "sauteed",
    "steamed",
)
PREPARED_TERMS = (
    "biryani",
    "chapati",
    "curry",
    "dal",
    "dosa",
    "idli",
    "khichdi",
    "poha",
    "roti",
    "sabzi",
    "upma",
)


def classify_existing_foods(apps, schema_editor):
    Food = apps.get_model("foods", "Food")
    for food in Food.objects.only("id", "canonical_name", "food_type").iterator():
        name = f" {food.canonical_name.lower()} "
        state = "unspecified"
        if food.food_type == "branded":
            state = "as_sold"
        elif any(term in name for term in RAW_TERMS):
            state = "raw"
        elif any(term in name for term in COOKED_TERMS):
            state = "cooked"
        elif any(term in name for term in PREPARED_TERMS):
            state = "prepared"
        if state != "unspecified":
            Food.objects.filter(pk=food.pk).update(preparation_state=state)


class Migration(migrations.Migration):
    dependencies = [
        ("foods", "0006_userportionpreference"),
    ]

    operations = [
        migrations.AddField(
            model_name="food",
            name="preparation_state",
            field=models.CharField(
                choices=[
                    ("unspecified", "Not specified"),
                    ("raw", "Raw"),
                    ("cooked", "Cooked"),
                    ("prepared", "Prepared dish"),
                    ("as_sold", "As sold / packaged"),
                ],
                default="unspecified",
                help_text=(
                    "Distinguishes raw, cooked, prepared, and packaged nutrition."
                ),
                max_length=20,
            ),
        ),
        migrations.RunPython(classify_existing_foods, migrations.RunPython.noop),
    ]
