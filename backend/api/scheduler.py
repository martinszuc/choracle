from datetime import date
from decimal import Decimal

from apscheduler.schedulers.background import BackgroundScheduler
from django_apscheduler.jobstores import DjangoJobStore


def generate_due_chores():
    from .models import DefaultChore, Chore
    from .views import _week_id

    today = date.today()
    for template in DefaultChore.objects.select_related('household', 'assigned_to').all():
        if today < template.start_date:
            continue
        if template.last_generated:
            days_since = (today - template.last_generated).days
            if days_since < template.frequency_days:
                continue
        Chore.objects.create(
            household=template.household,
            name=template.name,
            assigned_to=template.assigned_to,
            original_assigned_to=template.assigned_to,
            week_identifier=_week_id(today),
        )
        template.last_generated = today
        template.save(update_fields=['last_generated'])


def process_recurring_transactions():
    from .models import Transaction, Debt
    from .views import _advance_date, _spawn_transaction_debts

    today = date.today()
    due = Transaction.objects.filter(
        is_recurring=True, next_payment_date__lte=today
    ).prefetch_related('participants').select_related('creditor', 'household')

    for template in due:
        instance = Transaction.objects.create(
            household=template.household,
            creditor=template.creditor,
            amount=template.amount,
            description=template.description,
            is_recurring=False,
        )
        instance.participants.set(template.participants.all())
        _spawn_transaction_debts(instance)

        if template.recurrence_interval == 'once':
            template.delete()
        else:
            template.next_payment_date = _advance_date(template.next_payment_date, template.recurrence_interval)
            template.save(update_fields=['next_payment_date'])


def start_scheduler():
    scheduler = BackgroundScheduler()
    scheduler.add_jobstore(DjangoJobStore(), 'default')

    scheduler.add_job(
        generate_due_chores,
        trigger='cron',
        hour=0,
        minute=0,
        id='generate_due_chores',
        replace_existing=True,
    )
    scheduler.add_job(
        process_recurring_transactions,
        trigger='cron',
        hour=0,
        minute=0,
        id='process_recurring_transactions',
        replace_existing=True,
    )

    scheduler.start()
