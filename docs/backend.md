# Backend

Django REST Framework. All views are function-based (`@api_view`). No authentication — single trusted household. The household record is always fetched via `Household.objects.first()` ([`views.py:22`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L22)).

---

## Models

All PKs are UUID. Source: [`backend/api/models.py`](https://github.com/martinszuc/choracle/blob/main/backend/api/models.py)

**Household** — `id, name`. One record in the DB. Every other model FKs into it.

**Member** — `id, household, name, color`. Color is auto-generated from `hash(name) % 360` as an HSL string if not provided ([`models.py:5`](https://github.com/martinszuc/choracle/blob/main/backend/api/models.py#L5)) — same name always gets the same hue.

**Chore** — `id, household, name, assigned_to, original_assigned_to, completed, completed_by, completed_at, week_identifier, created_at`. Both assignment FKs are stored: take-over only changes `assigned_to`. The stats system compares the two to detect take-overs ([`views.py:139`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L139)).

**DefaultChore** — `id, household, name, assigned_to, frequency_days, start_date, last_generated`. Chore template read by the scheduler. `last_generated` prevents duplicate generation within the same interval.

**MemberStats** — `id, household, member (1:1), completed_count, taken_over_count, weekly_history (JSONField), daily_history (JSONField)`. History dicts keyed by ISO week (`"2026-W17"`) and date (`"2026-04-27"`), incremented in-place on each completion. No aggregation queries needed.

**Transaction** — `id, household, creditor, participants (M2M), amount, description, is_recurring, recurrence_interval, next_payment_date, start_date, is_settlement, created_at`. One model for both immediate and recurring transactions. Settlement transactions cannot be edited.

**ShoppingItem** — `id, household, name, quantity, purchased, created_by, purchased_by, debt_option ('none'|'single'|'group'), linked_transaction, created_at`.

**Debt** — `id, household, creditor, debtor, amount, related_transaction, created_at`. One row per debtor per transaction. The list endpoint aggregates with `GROUP BY + SUM` to show one net total per pair.

---

## API Endpoints

Source: [`backend/api/urls.py`](https://github.com/martinszuc/choracle/blob/main/backend/api/urls.py)

| Method | Path | Description |
|---|---|---|
| GET | `/api/household/` | Household + member list |
| POST | `/api/members/` | Add member |
| DELETE | `/api/members/{id}/` | Remove member |
| GET | `/api/chores/` | Week's chores (`?week=2026-W17`) |
| POST | `/api/chores/` | Create immediate chore |
| PUT | `/api/chores/{id}/complete/` | Mark done, update stats |
| PUT | `/api/chores/{id}/assign/` | Take over |
| DELETE | `/api/chores/{id}/` | Delete chore |
| GET/POST | `/api/default-chores/` | List / create templates |
| DELETE | `/api/default-chores/{id}/` | Remove template |
| GET | `/api/stats/` | Member stats (`?member_id=...`) |
| GET/POST | `/api/shopping-items/` | List / add items (POST accepts array) |
| PUT/DELETE | `/api/shopping-items/{id}/` | Update / remove item |
| GET/POST | `/api/favorite-items/` | List / add favorites |
| DELETE | `/api/favorite-items/{id}/` | Remove favorite |
| GET/POST | `/api/transactions/` | History / create |
| PUT/DELETE | `/api/transactions/{id}/` | Edit / delete |
| GET | `/api/transactions/recurring/` | Scheduled templates |
| GET | `/api/transactions/{id}/can-edit/` | Edit eligibility |
| GET | `/api/debts/` | Aggregated debts (GROUP BY pair) |
| POST | `/api/debts/settle/` | Full or partial settlement |

---

## Key Implementation Details

**Debt splitting** ([`views.py:40`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L40)) — On transaction create, `_spawn_transaction_debts` divides amount equally among non-creditor participants and inserts one `Debt` row per person. Debts are pre-split at write time.

**Debt aggregation** ([`views.py:366`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L366)) — `debt_list` uses `.values(...).annotate(total=Sum('amount'))` — one SQL query, one net row per debtor→creditor pair.

**Partial settlement** ([`views.py:389`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L389)) — Deletes all existing Debt rows between the pair, creates a Settlement transaction, then re-creates a single remainder Debt if `partial_amount < total`.

**Edit guard** ([`views.py:343`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L343)) — `can_edit` checks if the transaction is a settlement or if any of its debts are already cleared. Returns `{can_edit: false, reason: "..."}`. The UI checks this before opening the edit form.

**`_advance_date`** ([`views.py:30`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L30)) — Maps interval strings to timedeltas: `monthly = 30 days`, `semiannually = 182 days`. `once` recurrence deletes the template after first fire ([`scheduler.py:51`](https://github.com/martinszuc/choracle/blob/main/backend/api/scheduler.py#L51)).

---

## Scheduler

Source: [`backend/api/scheduler.py`](https://github.com/martinszuc/choracle/blob/main/backend/api/scheduler.py) — started in `AppConfig.ready()`, runs at `00:00` daily via `DjangoJobStore`.

**`generate_due_chores`** — For each `DefaultChore`: checks `start_date` passed and `frequency_days` elapsed since `last_generated`. If yes → creates a `Chore` for the current week, updates `last_generated`.

**`process_recurring_transactions`** — Finds all `Transaction` where `is_recurring=True` and `next_payment_date <= today`. For each: clones a non-recurring instance, spawns debts, then either deletes the template (`once`) or advances `next_payment_date`.
