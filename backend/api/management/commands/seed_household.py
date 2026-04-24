import os

from django.core.management.base import BaseCommand

from api.models import Household


class Command(BaseCommand):
    help = 'Create the default household if none exists.'

    def handle(self, *args, **options):
        if Household.objects.exists():
            self.stdout.write('Household already exists, skipping.')
            return
        name = os.environ.get('HOUSEHOLD_NAME', 'Home')
        Household.objects.create(name=name)
        self.stdout.write(f'Created household: {name}')
