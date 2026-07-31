import django.core.validators
import django.db.models.deletion
import uuid
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True
    dependencies = [migrations.swappable_dependency(settings.AUTH_USER_MODEL)]
    operations = [
        migrations.CreateModel(
            name="DailyActivity",
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
                ("activity_date", models.DateField()),
                (
                    "activity_type",
                    models.CharField(
                        choices=[("workout", "Workout"), ("steps", "Steps")],
                        max_length=16,
                    ),
                ),
                ("title", models.CharField(blank=True, max_length=160)),
                ("duration_minutes", models.PositiveIntegerField(default=0)),
                ("steps", models.PositiveIntegerField(default=0)),
                (
                    "calories_burned",
                    models.DecimalField(
                        decimal_places=2,
                        default=0,
                        max_digits=8,
                        validators=[django.core.validators.MinValueValidator(0)],
                    ),
                ),
                ("notes", models.TextField(blank=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="%(app_label)s_%(class)s_items",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"ordering": ("-activity_date", "-created_at")},
        ),
        migrations.CreateModel(
            name="ReminderPreference",
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
                ("meal_reminders", models.BooleanField(default=False)),
                ("meal_reminder_time", models.TimeField(blank=True, null=True)),
                ("water_reminders", models.BooleanField(default=False)),
                (
                    "water_reminder_interval_minutes",
                    models.PositiveIntegerField(default=120),
                ),
                ("habit_reminders", models.BooleanField(default=False)),
                ("habit_reminder_time", models.TimeField(blank=True, null=True)),
                ("weight_reminders", models.BooleanField(default=False)),
                (
                    "weight_reminder_weekday",
                    models.PositiveSmallIntegerField(default=0),
                ),
                ("weekly_report", models.BooleanField(default=True)),
                (
                    "user",
                    models.OneToOneField(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="reminder_preference",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
        ),
        migrations.CreateModel(
            name="WaterIntakeEntry",
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
                ("entry_date", models.DateField()),
                (
                    "amount_ml",
                    models.PositiveIntegerField(
                        validators=[django.core.validators.MinValueValidator(1)]
                    ),
                ),
                ("note", models.CharField(blank=True, max_length=180)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="%(app_label)s_%(class)s_items",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"ordering": ("-entry_date", "-created_at")},
        ),
        migrations.AddIndex(
            model_name="dailyactivity",
            index=models.Index(
                fields=["user", "activity_date", "activity_type"],
                name="tracking_da_user_id_959a64_idx",
            ),
        ),
        migrations.AddIndex(
            model_name="reminderpreference",
            index=models.Index(
                fields=["user", "updated_at"], name="tracking_re_user_id_46f02d_idx"
            ),
        ),
        migrations.AddIndex(
            model_name="waterintakeentry",
            index=models.Index(
                fields=["user", "entry_date"], name="tracking_wa_user_id_836c88_idx"
            ),
        ),
    ]
