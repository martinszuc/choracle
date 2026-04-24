import uuid
from django.db import models


def _color_from_name(name: str) -> str:
    hue = hash(name) % 360
    return f'hsl({hue},60%,50%)'


class Household(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)

    def __str__(self):
        return self.name


class Member(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    household = models.ForeignKey(Household, on_delete=models.CASCADE, related_name='members')
    name = models.CharField(max_length=255)
    color = models.CharField(max_length=50)

    def save(self, *args, **kwargs):
        if not self.color:
            self.color = _color_from_name(self.name)
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name


class DefaultChore(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    household = models.ForeignKey(Household, on_delete=models.CASCADE, related_name='default_chores')
    name = models.CharField(max_length=255)
    frequency_days = models.IntegerField()
    start_date = models.DateField()
    last_generated = models.DateField(null=True, blank=True)

    def __str__(self):
        return self.name


class Chore(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    household = models.ForeignKey(Household, on_delete=models.CASCADE, related_name='chores')
    name = models.CharField(max_length=255)
    assigned_to = models.ForeignKey(
        Member, on_delete=models.SET_NULL, null=True, blank=True, related_name='chores_assigned'
    )
    original_assigned_to = models.ForeignKey(
        Member, on_delete=models.SET_NULL, null=True, blank=True, related_name='chores_original'
    )
    completed = models.BooleanField(default=False)
    completed_by = models.ForeignKey(
        Member, on_delete=models.SET_NULL, null=True, blank=True, related_name='chores_completed'
    )
    completed_at = models.DateTimeField(null=True, blank=True)
    week_identifier = models.CharField(max_length=10)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class MemberStats(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    household = models.ForeignKey(Household, on_delete=models.CASCADE, related_name='member_stats')
    member = models.OneToOneField(Member, on_delete=models.CASCADE, related_name='stats')
    completed_count = models.IntegerField(default=0)
    taken_over_count = models.IntegerField(default=0)
    weekly_history = models.JSONField(default=dict)
    daily_history = models.JSONField(default=dict)

    def __str__(self):
        return f'Stats for {self.member}'


class FavoriteItem(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    household = models.ForeignKey(Household, on_delete=models.CASCADE, related_name='favorite_items')
    name = models.CharField(max_length=255)

    def __str__(self):
        return self.name


class Transaction(models.Model):
    RECURRENCE_CHOICES = [
        ('once', 'Once'),
        ('weekly', 'Weekly'),
        ('biweekly', 'Biweekly'),
        ('monthly', 'Monthly'),
        ('semiannually', 'Semiannually'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    household = models.ForeignKey(Household, on_delete=models.CASCADE, related_name='transactions')
    creditor = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='transactions_as_creditor')
    participants = models.ManyToManyField(Member, related_name='transactions_as_participant', blank=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    description = models.CharField(max_length=500, blank=True)
    is_recurring = models.BooleanField(default=False)
    recurrence_interval = models.CharField(
        max_length=20, choices=RECURRENCE_CHOICES, null=True, blank=True
    )
    next_payment_date = models.DateField(null=True, blank=True)
    start_date = models.DateField(null=True, blank=True)
    is_settlement = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.description or str(self.id)


class ShoppingItem(models.Model):
    DEBT_CHOICES = [
        ('none', 'None'),
        ('single', 'Single'),
        ('group', 'Group'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    household = models.ForeignKey(Household, on_delete=models.CASCADE, related_name='shopping_items')
    name = models.CharField(max_length=255)
    quantity = models.IntegerField(default=1)
    purchased = models.BooleanField(default=False)
    created_by = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='shopping_items_created')
    purchased_by = models.ForeignKey(
        Member, on_delete=models.SET_NULL, null=True, blank=True, related_name='shopping_items_purchased'
    )
    debt_option = models.CharField(max_length=10, choices=DEBT_CHOICES, default='none')
    linked_transaction = models.ForeignKey(
        Transaction, on_delete=models.SET_NULL, null=True, blank=True, related_name='linked_items'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class Debt(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    household = models.ForeignKey(Household, on_delete=models.CASCADE, related_name='debts')
    creditor = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='debts_owed_to')
    debtor = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='debts_owed_by')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    related_transaction = models.ForeignKey(
        Transaction, on_delete=models.SET_NULL, null=True, blank=True, related_name='debts'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.debtor} owes {self.creditor} {self.amount}'
