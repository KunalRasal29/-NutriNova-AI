from django.core.management.base import BaseCommand, CommandError

from foods.importers import get_env
from foods.services.openfoodfacts import sync_openfoodfacts_product


class Command(BaseCommand):
    help = "Sync a packaged product from Open Food Facts API v3 by barcode."

    def add_arguments(self, parser):
        parser.add_argument("--barcode", required=True)

    def handle(self, *args, **options):
        user_agent = get_env("OPENFOODFACTS_USER_AGENT")
        if not user_agent:
            raise CommandError("OPENFOODFACTS_USER_AGENT is required for OFF sync.")

        barcode = options["barcode"]
        food = sync_openfoodfacts_product(barcode, user_agent=user_agent)
        if food is None:
            self.stdout.write(self.style.WARNING(f"No product found for {barcode}."))
            return
        self.stdout.write(self.style.SUCCESS(f"Synced {food} from Open Food Facts."))
