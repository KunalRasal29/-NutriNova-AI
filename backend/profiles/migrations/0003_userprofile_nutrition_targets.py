from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("profiles", "0002_userprofile_allergies_userprofile_country_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="userprofile",
            name="daily_calorie_target_kcal",
            field=models.DecimalField(
                blank=True,
                decimal_places=1,
                max_digits=7,
                null=True,
            ),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="daily_protein_target_g",
            field=models.DecimalField(
                blank=True,
                decimal_places=1,
                max_digits=6,
                null=True,
            ),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="daily_carbs_target_g",
            field=models.DecimalField(
                blank=True,
                decimal_places=1,
                max_digits=6,
                null=True,
            ),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="daily_fat_target_g",
            field=models.DecimalField(
                blank=True,
                decimal_places=1,
                max_digits=6,
                null=True,
            ),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="daily_fiber_target_g",
            field=models.DecimalField(
                blank=True,
                decimal_places=1,
                max_digits=5,
                null=True,
            ),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="daily_water_target_ml",
            field=models.DecimalField(
                blank=True,
                decimal_places=1,
                max_digits=7,
                null=True,
            ),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="nutrition_target_method",
            field=models.CharField(blank=True, max_length=64),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="nutrition_targets_calculated_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="nutrition_targets_customized",
            field=models.BooleanField(default=False),
        ),
    ]
