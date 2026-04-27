# Backend

Django REST Framework backend. All views are function-based (`@api_view`). No authentication — the app assumes a single trusted household. The single Household record is always fetched via `Household.objects.first()` ([`views.py:22`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L22)).

---

## Models

All primary keys are UUID (`uuid.uuid4`), not auto-increment integers. This avoids ID collisions if the DB is ever migrated or seeded.

Source: [`backend/api/models.py`](https://github.com/martinszuc/choracle/blob/main/backend/api/models.py)

### Household
```
id (UUID PK) | name
```
One record in the DB. All other models FK into this.

### Member
```
id | household (FK) | name | color
```
`color` is auto-generated from the member's name if not provided — a deterministic HSL value from `hash(name) % 360` ([`models.py:5–7`](https://github.com/martinszuc/choracle/blob/main/backend/api/models.py#L5)). This means the same name always gets the same hue, which makes avatars consistent without requiring a color picker.

### Chore
```
id | household | name | assigned_to (FK Member, nullable)
   | original_assigned_to (FK Member, nullable)
   | completed (bool) | completed_by (FK Member, nullable) | completed_at
   | week_identifier (str, e.g. "2026-W17") | created_at
```
`week_identifier` scopes chores to a single week — the frontend requests `GET /chores/?week=2026-W17`. Both `assigned_to` and `original_assigned_to` are stored: when someone takes over a chore, only `assigned_to` changes. The difference between them is how the stats system detects and counts take-overs ([`views.py:139`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L139)).

### DefaultChore (scheduled chore template)
```
id | household | name | assigned_to (FK Member, nullable)
   | frequency_days (int) | start_date | last_generated (nullable)
```
The scheduler reads these every midnight. `last_generated` is updated each time a `Chore` is spawned from this template, preventing duplicate generation within the same interval ([`scheduler.py:16–19`](https://github.com/martinszuc/choracle/blob/main/backend/api/scheduler.py#L16)).

### MemberStats
```
id | household | member (OneToOne) | completed_count | taken_over_count
   | weekly_history (JSONField) | daily_history (JSONField)
```
`weekly_history`: `{"2026-W17": 3, "2026-W16": 1, ...}`  
`daily_history`: `{"2026-04-27": 2, "2026-04-26": 1, ...}`

Updated in-place on every `chore_complete` call ([`views.py:136–140`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L136)). No historical recalculation needed — the dict grows over time.

### Transaction
```
id | household | creditor (FK Member) | participants (M2M Member)
   | amount (Decimal 10,2) | description | is_recurring (bool)
   | recurrence_interval ('once'|'weekly'|'biweekly'|'monthly'|'semiannually')
   | next_payment_date | start_date | is_settlement (bool) | created_at
```
One model serves both immediate transactions and scheduled payment templates (`is_recurring=True`). Settlement transactions (`is_settlement=True`) are created by the debt-settle endpoint and cannot be edited — enforced by the `can-edit` guard ([`views.py:350`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L350)).

### ShoppingItem
```
id | household | name | quantity (int) | purchased (bool)
   | created_by (FK Member) | purchased_by (FK Member, nullable)
   | debt_option ('none'|'single'|'group')
   | linked_transaction (FK Transaction, nullable) | created_at
```
`debt_option` is set at item creation — before purchase. On purchase the frontend creates a transaction and links it to this item via `linked_transaction`.

### Debt
```
id | household | creditor (FK Member) | debtor (FK Member)
   | amount (Decimal 10,2) | related_transaction (FK Transaction, nullable) | created_at
```
Individual debt rows — one per debtor per transaction. The `debt_list` endpoint aggregates these with a `GROUP BY` + `SUM` at the DB level, so the frontend always receives one net row per debtor→creditor pair ([`views.py:366–386`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L366)).

---

## API Endpoints

Source: [`backend/api/urls.py`](https://github.com/martinszuc/choracle/blob/main/backend/api/urls.py)

| Method | Path | Description |
|---|---|---|
| GET | `/api/household/` | Household name + member list |
| POST | `/api/members/` | Add a member (auto-assigns color) |
| DELETE | `/api/members/{id}/` | Remove a member |
| GET | `/api/chores/` | Week's chores (`?week=2026-W17`) |
| POST | `/api/chores/` | Create immediate chore |
| PUT | `/api/chores/{id}/complete/` | Mark done, update stats |
| PUT | `/api/chores/{id}/assign/` | Take over (reassign) |
| DELETE | `/api/chores/{id}/` | Delete chore |
| GET | `/api/default-chores/` | Scheduled chore templates |
| POST | `/api/default-chores/` | Create template |
| DELETE | `/api/default-chores/{id}/` | Remove template |
| GET | `/api/stats/` | Member stats (`?member_id=...`) |
| GET | `/api/shopping-items/` | All items (unpurchased first) |
| POST | `/api/shopping-items/` | Add item(s) — accepts list |
| PUT | `/api/shopping-items/{id}/` | Update (mark purchased, link transaction) |
| DELETE | `/api/shopping-items/{id}/` | Remove item |
| GET | `/api/favorite-items/` | Household favorites |
| POST | `/api/favorite-items/` | Add favorite |
| DELETE | `/api/favorite-items/{id}/` | Remove favorite |
| GET | `/api/transactions/` | All non-recurring transactions |
| POST | `/api/transactions/` | Create transaction (spawns debts) |
| PUT | `/api/transactions/{id}/` | Edit transaction |
| DELETE | `/api/transactions/{id}/` | Delete + cascade debts |
| GET | `/api/transactions/recurring/` | Scheduled payment templates |
| GET | `/api/transactions/{id}/can-edit/` | Edit eligibility check |
| GET | `/api/debts/` | Aggregated debts (GROUP BY pair) |
| POST | `/api/debts/settle/` | Full or partial settlement |

---

## Key Implementation Details

### Debt splitting — `_spawn_transaction_debts`
[`views.py:40–53`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L40)

When a transaction is created, the backend immediately divides the amount equally among all non-creditor participants and creates one `Debt` row per person:

```python
share = transaction.amount / Decimal(len(participants))
for member in non_creditors:
    Debt.objects.create(creditor=..., debtor=member, amount=share, ...)
```

This means debts are pre-split at write time, not computed on read. The `debt_list` view then aggregates them across all transactions with `SUM`.

### Debt aggregation — no ORM join gymnastics
[`views.py:366–386`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L366)

```python
Debt.objects.filter(...).values('debtor__id', 'creditor__id', ...).annotate(total=Sum('amount'))
```

One SQL query returns all debtor→creditor pairs with their running totals. No Python loops, no N+1.

### Partial settlement
[`views.py:389–432`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L389)

Settlement deletes all existing `Debt` rows between the pair, creates a `Settlement` transaction record, then re-creates a single remainder `Debt` if `partial_amount < total`. This keeps the debt table tidy — one row per pair after any settlement.

### Edit guard — `can_edit`
[`views.py:343–360`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L343)

Before allowing an edit, the backend checks: is this a settlement? Are any of its debts already cleared? Returns `{can_edit: false, reason: "..."}`. The UI respects this before opening the edit form.

### Recurring transactions — `_advance_date`
[`views.py:30–37`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L30)

```python
intervals = {
    'weekly': timedelta(weeks=1),
    'biweekly': timedelta(weeks=2),
    'monthly': timedelta(days=30),
    'semiannually': timedelta(days=182),
}
```

`monthly` is 30 days (not calendar month) for simplicity. When a recurring transaction fires, `next_payment_date` advances by this delta. `once` recurrence is special — the template deletes itself after the first fire ([`scheduler.py:51–52`](https://github.com/martinszuc/choracle/blob/main/backend/api/scheduler.py#L51)).

---

## Scheduler

Source: [`backend/api/scheduler.py`](https://github.com/martinszuc/choracle/blob/main/backend/api/scheduler.py)

Two jobs, both fire daily at `00:00`:

**`generate_due_chores`** ([`scheduler.py:8–28`](https://github.com/martinszuc/choracle/blob/main/backend/api/scheduler.py#L8))  
Iterates all `DefaultChore` templates. For each: checks if `start_date` has passed and if `frequency_days` have elapsed since `last_generated`. If yes → creates a new `Chore` for the current week and stamps `last_generated = today`.

**`process_recurring_transactions`** ([`scheduler.py:31–55`](https://github.com/martinszuc/choracle/blob/main/backend/api/scheduler.py#L31))  
Finds all `Transaction` records where `is_recurring=True` and `next_payment_date <= today`. For each: clones a non-recurring instance with the same creditor/participants/amount, spawns debts, then either deletes the template (`once`) or advances `next_payment_date`.

The scheduler is started in `api/apps.py` via `AppConfig.ready()`, which means it starts with the Django process. It uses `DjangoJobStore` so job state survives restarts.

```
Midnight cron
│
├── generate_due_chores
│   └── For each DefaultChore where elapsed >= frequency_days:
│       └── INSERT Chore (current week) + UPDATE last_generated
│
└── process_recurring_transactions
    └── For each Transaction where next_payment_date <= today:
        ├── INSERT Transaction (non-recurring copy)
        ├── _spawn_transaction_debts (INSERT Debt rows)
        └── DELETE template (once) OR UPDATE next_payment_date
```
