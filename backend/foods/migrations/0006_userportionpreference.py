import uuid

import django.db.models.deletion
import django.utils.timezone
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("foods", "0005_grocerylist_grocerylistitem_pantryitem_and_more"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="UserPortionPreference",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        default=uuid.uuid4,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("unit", models.CharField(max_length=32)),
                (
                    "grams_per_unit",
                    models.DecimalField(decimal_places=3, max_digits=10),
                ),
                ("times_used", models.PositiveIntegerField(default=1)),
                (
                    "last_used_at",
                    models.DateTimeField(default=django.utils.timezone.now),
                ),
                (
                    "food",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="user_portion_preferences",
                        to="foods.food",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="%(app_label)s_%(class)s_items",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ("-last_used_at",),
                "indexes": [
                    models.Index(
                        fields=["user", "food", "unit"],
                        name="foods_userp_user_id_e480fe_idx",
                    ),
                    models.Index(
                        fields=["user", "last_used_at"],
                        name="foods_userp_user_id_d82bf9_idx",
                    ),
                ],
                "constraints": [
                    models.UniqueConstraint(
                        fields=("user", "food", "unit"),
                        name="unique_portion_preference_per_user_food_unit",
                    )
                ],
            },
        ),
    ]
