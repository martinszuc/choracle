from django.apps import AppConfig


class ApiConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'api'

    def ready(self):
        import sys
        from django.conf import settings
        if settings.TESTING:
            return
        # manage.py commands (migrate, collectstatic, etc.) run before DB tables
        # exist — only start the scheduler when serving under gunicorn/wsgi
        running_via_manage = any('manage' in arg for arg in sys.argv[:1])
        if running_via_manage:
            return
        from .scheduler import start_scheduler
        start_scheduler()
