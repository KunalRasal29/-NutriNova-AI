from django.contrib import admin

from tracking.models import DailyActivity, ReminderPreference, WaterIntakeEntry

admin.site.register(WaterIntakeEntry)
admin.site.register(DailyActivity)
admin.site.register(ReminderPreference)
