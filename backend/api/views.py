from datetime import date, timedelta
from decimal import Decimal

from django.db.models import Sum
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .models import (
    Household, Member, DefaultChore, Chore, MemberStats,
    FavoriteItem, ShoppingItem, Transaction, Debt,
)
from .serializers import (
    HouseholdSerializer, MemberSerializer, DefaultChoreSerializer,
    ChoreSerializer, MemberStatsSerializer, FavoriteItemSerializer,
    ShoppingItemSerializer, TransactionSerializer, DebtAggregatedSerializer,
)


def _get_household():
    return Household.objects.prefetch_related('members').first()


def _week_id(d: date) -> str:
    iso = d.isocalendar()
    return f'{iso[0]}-W{iso[1]:02d}'


def _advance_date(d: date, interval: str) -> date:
    intervals = {
        'weekly': timedelta(weeks=1),
        'biweekly': timedelta(weeks=2),
        'monthly': timedelta(days=30),
        'semiannually': timedelta(days=182),
    }
    return d + intervals.get(interval, timedelta(days=0))


def _spawn_transaction_debts(transaction: Transaction):
    participants = list(transaction.participants.all())
    non_creditors = [p for p in participants if p.id != transaction.creditor.id]
    if not non_creditors:
        return
    share = transaction.amount / Decimal(len(participants))
    for member in non_creditors:
        Debt.objects.create(
            household=transaction.household,
            creditor=transaction.creditor,
            debtor=member,
            amount=share,
            related_transaction=transaction,
        )


# ── Household ──────────────────────────────────────────────────────────────

@api_view(['GET'])
def household_detail(request):
    household = _get_household()
    if not household:
        return Response({'detail': 'No household configured.'}, status=404)
    return Response(HouseholdSerializer(household).data)


# ── Members ────────────────────────────────────────────────────────────────

@api_view(['POST'])
def member_create(request):
    household = _get_household()
    if not household:
        return Response({'detail': 'No household.'}, status=400)
    data = {**request.data, 'household': str(household.id)}
    serializer = MemberSerializer(data=data)
    if serializer.is_valid():
        member = serializer.save()
        MemberStats.objects.create(household=household, member=member)
        return Response(MemberSerializer(member).data, status=201)
    return Response(serializer.errors, status=400)


@api_view(['DELETE'])
def member_delete(request, pk):
    try:
        member = Member.objects.get(pk=pk)
    except Member.DoesNotExist:
        return Response(status=404)
    member.delete()
    return Response(status=204)


# ── Chores ─────────────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
def chore_list_create(request):
    household = _get_household()
    if request.method == 'GET':
        week = request.query_params.get('week', _week_id(date.today()))
        chores = Chore.objects.filter(household=household, week_identifier=week).select_related(
            'assigned_to', 'original_assigned_to', 'completed_by'
        )
        return Response(ChoreSerializer(chores, many=True).data)

    data = {**request.data, 'household': str(household.id), 'week_identifier': _week_id(date.today())}
    serializer = ChoreSerializer(data=data)
    if serializer.is_valid():
        chore = serializer.save(week_identifier=_week_id(date.today()))
        return Response(ChoreSerializer(chore).data, status=201)
    return Response(serializer.errors, status=400)


@api_view(['PUT'])
def chore_complete(request, pk):
    try:
        chore = Chore.objects.select_related('assigned_to', 'original_assigned_to').get(pk=pk)
    except Chore.DoesNotExist:
        return Response(status=404)

    completed_by_id = request.data.get('completed_by')
    try:
        completer = Member.objects.get(id=completed_by_id)
    except Member.DoesNotExist:
        return Response({'detail': 'Member not found.'}, status=400)

    chore.completed = True
    chore.completed_by = completer
    chore.completed_at = timezone.now()
    chore.save()

    stats, _ = MemberStats.objects.get_or_create(
        member=completer,
        defaults={'household': chore.household},
    )
    stats.completed_count += 1
    week = _week_id(date.today())
    stats.weekly_history[week] = stats.weekly_history.get(week, 0) + 1
    today_str = date.today().isoformat()
    stats.daily_history[today_str] = stats.daily_history.get(today_str, 0) + 1
    if chore.original_assigned_to and chore.original_assigned_to.id != completer.id:
        stats.taken_over_count += 1
    stats.save()

    return Response(ChoreSerializer(chore).data)


@api_view(['PUT'])
def chore_assign(request, pk):
    try:
        chore = Chore.objects.get(pk=pk)
    except Chore.DoesNotExist:
        return Response(status=404)

    member_id = request.data.get('member_id')
    try:
        member = Member.objects.get(id=member_id)
    except Member.DoesNotExist:
        return Response({'detail': 'Member not found.'}, status=400)

    chore.assigned_to = member
    chore.save()
    return Response(ChoreSerializer(chore).data)


@api_view(['DELETE'])
def chore_delete(request, pk):
    try:
        chore = Chore.objects.get(pk=pk)
    except Chore.DoesNotExist:
        return Response(status=404)
    chore.delete()
    return Response(status=204)


# ── Default Chores ─────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
def default_chore_list_create(request):
    household = _get_household()
    if request.method == 'GET':
        items = DefaultChore.objects.filter(household=household)
        return Response(DefaultChoreSerializer(items, many=True).data)

    data = {**request.data, 'household': str(household.id)}
    serializer = DefaultChoreSerializer(data=data)
    if serializer.is_valid():
        obj = serializer.save()
        today = date.today()
        if obj.start_date <= today:
            Chore.objects.create(
                household=obj.household,
                name=obj.name,
                assigned_to=obj.assigned_to,
                original_assigned_to=obj.assigned_to,
                week_identifier=_week_id(today),
            )
            obj.last_generated = today
            obj.save(update_fields=['last_generated'])
        return Response(DefaultChoreSerializer(obj).data, status=201)
    return Response(serializer.errors, status=400)


@api_view(['DELETE'])
def default_chore_delete(request, pk):
    try:
        obj = DefaultChore.objects.get(pk=pk)
    except DefaultChore.DoesNotExist:
        return Response(status=404)
    obj.delete()
    return Response(status=204)


# ── Stats ──────────────────────────────────────────────────────────────────

@api_view(['GET'])
def stats_detail(request):
    member_id = request.query_params.get('member_id')
    try:
        stats = MemberStats.objects.get(member__id=member_id)
    except MemberStats.DoesNotExist:
        return Response({'detail': 'Stats not found.'}, status=404)
    return Response(MemberStatsSerializer(stats).data)


# ── Shopping Items ─────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
def shopping_item_list_create(request):
    household = _get_household()
    if request.method == 'GET':
        items = ShoppingItem.objects.filter(household=household).select_related(
            'created_by', 'purchased_by'
        ).order_by('purchased', 'created_at')
        return Response(ShoppingItemSerializer(items, many=True).data)

    items_data = request.data if isinstance(request.data, list) else [request.data]
    created = []
    for item_data in items_data:
        data = {**item_data, 'household': str(household.id)}
        serializer = ShoppingItemSerializer(data=data)
        if serializer.is_valid():
            created.append(serializer.save())
        else:
            return Response(serializer.errors, status=400)
    return Response(ShoppingItemSerializer(created, many=True).data, status=201)


@api_view(['PUT', 'DELETE'])
def shopping_item_detail(request, pk):
    try:
        item = ShoppingItem.objects.get(pk=pk)
    except ShoppingItem.DoesNotExist:
        return Response(status=404)

    if request.method == 'DELETE':
        item.delete()
        return Response(status=204)

    serializer = ShoppingItemSerializer(item, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data)
    return Response(serializer.errors, status=400)


# ── Favorite Items ─────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
def favorite_item_list_create(request):
    household = _get_household()
    if request.method == 'GET':
        items = FavoriteItem.objects.filter(household=household)
        return Response(FavoriteItemSerializer(items, many=True).data)

    data = {**request.data, 'household': str(household.id)}
    serializer = FavoriteItemSerializer(data=data)
    if serializer.is_valid():
        obj = serializer.save()
        return Response(FavoriteItemSerializer(obj).data, status=201)
    return Response(serializer.errors, status=400)


@api_view(['DELETE'])
def favorite_item_delete(request, pk):
    try:
        obj = FavoriteItem.objects.get(pk=pk)
    except FavoriteItem.DoesNotExist:
        return Response(status=404)
    obj.delete()
    return Response(status=204)


# ── Transactions ───────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
def transaction_list_create(request):
    household = _get_household()
    if request.method == 'GET':
        txs = Transaction.objects.filter(
            household=household, is_recurring=False
        ).prefetch_related('participants').select_related('creditor').order_by('-created_at')
        return Response(TransactionSerializer(txs, many=True).data)

    data = {**request.data, 'household': str(household.id)}
    serializer = TransactionSerializer(data=data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=400)

    is_recurring = data.get('is_recurring', False)
    start_date_str = data.get('start_date')
    start_date = date.fromisoformat(start_date_str) if start_date_str else None

    transaction = serializer.save()

    if not is_recurring:
        _spawn_transaction_debts(transaction)
    elif start_date and start_date <= date.today():
        _spawn_transaction_debts(transaction)
        interval = transaction.recurrence_interval
        if interval and interval != 'once':
            transaction.next_payment_date = _advance_date(start_date, interval)
            transaction.save()

    return Response(TransactionSerializer(transaction).data, status=201)


@api_view(['GET'])
def transaction_recurring_list(request):
    household = _get_household()
    txs = Transaction.objects.filter(
        household=household, is_recurring=True
    ).prefetch_related('participants').select_related('creditor').order_by('next_payment_date')
    return Response(TransactionSerializer(txs, many=True).data)


@api_view(['PUT', 'DELETE'])
def transaction_detail(request, pk):
    try:
        tx = Transaction.objects.prefetch_related('participants').select_related('creditor').get(pk=pk)
    except Transaction.DoesNotExist:
        return Response(status=404)

    if request.method == 'DELETE':
        tx.debts.all().delete()
        tx.delete()
        return Response(status=204)

    if tx.is_settlement:
        return Response({'detail': 'Settlement transactions cannot be edited.'}, status=400)

    serializer = TransactionSerializer(tx, data=request.data, partial=True)
    if serializer.is_valid():
        updated_tx = serializer.save()
        if not updated_tx.is_recurring:
            updated_tx.debts.all().delete()
            _spawn_transaction_debts(updated_tx)
        return Response(TransactionSerializer(updated_tx).data)
    return Response(serializer.errors, status=400)


@api_view(['GET'])
def transaction_can_edit(request, pk):
    try:
        tx = Transaction.objects.prefetch_related('participants').get(pk=pk)
    except Transaction.DoesNotExist:
        return Response(status=404)

    if tx.is_settlement:
        return Response({'can_edit': False, 'reason': 'Settlement transactions cannot be edited.'})

    participant_count = tx.participants.count()
    non_creditor_count = sum(1 for p in tx.participants.all() if p.id != tx.creditor.id)
    debt_count = tx.debts.count()

    if debt_count < non_creditor_count:
        return Response({'can_edit': False, 'reason': 'Some debts have already been settled.'})

    return Response({'can_edit': True, 'reason': ''})


# ── Debts ──────────────────────────────────────────────────────────────────

@api_view(['GET'])
def debt_list(request):
    household = _get_household()
    raw = (
        Debt.objects
        .filter(household=household)
        .values('debtor__id', 'debtor__name', 'debtor__color', 'creditor__id', 'creditor__name', 'creditor__color')
        .annotate(total=Sum('amount'))
    )
    result = [
        {
            'debtor_id': r['debtor__id'],
            'debtor_name': r['debtor__name'],
            'debtor_color': r['debtor__color'],
            'creditor_id': r['creditor__id'],
            'creditor_name': r['creditor__name'],
            'creditor_color': r['creditor__color'],
            'amount': r['total'],
        }
        for r in raw
    ]
    return Response(DebtAggregatedSerializer(result, many=True).data)


@api_view(['POST'])
def debt_settle(request):
    household = _get_household()
    debtor_id = request.data.get('debtor_id')
    creditor_id = request.data.get('creditor_id')
    partial_amount = request.data.get('amount')

    try:
        debtor = Member.objects.get(id=debtor_id)
        creditor = Member.objects.get(id=creditor_id)
    except Member.DoesNotExist:
        return Response({'detail': 'Member not found.'}, status=400)

    debts = Debt.objects.filter(household=household, debtor=debtor, creditor=creditor)
    total = debts.aggregate(total=Sum('amount'))['total'] or Decimal('0')

    if partial_amount:
        settle_amount = Decimal(str(partial_amount))
        remainder = total - settle_amount
    else:
        settle_amount = total
        remainder = Decimal('0')

    debts.delete()

    # debtor is paying back, so they are the creditor of the settlement transaction
    settlement = Transaction.objects.create(
        household=household,
        creditor=debtor,
        amount=settle_amount,
        description=f'Settlement: {debtor.name} → {creditor.name}',
        is_settlement=True,
    )
    settlement.participants.set([creditor])

    if remainder > 0:
        Debt.objects.create(
            household=household,
            creditor=creditor,
            debtor=debtor,
            amount=remainder,
            related_transaction=settlement,
        )

    return Response(TransactionSerializer(settlement).data, status=201)
