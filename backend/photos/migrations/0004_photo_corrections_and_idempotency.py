import django.core.validators
import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("meals", "0002_remove_mealitem_meal_remove_mealitem_food_and_more"),
        ("photos", "0003_photodetectedfood_added_manually_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="photoanalysis",
            name="confirmed_meal",
            field=models.OneToOneField(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="source_photo_analysis",
                to="meals.meallog",
            ),
        ),
        migrations.AddField(
            model_name="photodetectedfood",
            name="eaten_percentage",
            field=models.DecimalField(
                decimal_places=2,
                default=100,
                max_digits=5,
                validators=[
                    django.core.validators.MinValueValidator(0),
                    django.core.validators.MaxValueValidator(100),
                ],
            ),
        ),
        migrations.AddField(
            model_name="photodetectedfood",
            name="split_parent",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="split_children",
                to="photos.photodetectedfood",
            ),
        ),
    ]
