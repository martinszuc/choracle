# Frontend

Flutter Android app, Material 3. All state lives in memory — no local database. State is managed with the `provider` package (`ChangeNotifier`).

---

## Provider Architecture

Source: [`frontend/lib/app.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/app.dart)

Four providers set up via `MultiProvider`. The three module providers depend on `AppProvider` via `ChangeNotifierProxyProvider` ([`app.dart:25`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/app.dart#L25)) — when `AppProvider` finishes loading the household, it propagates `householdId` to each child, which triggers their initial fetch automatically.

```
AppProvider (household, currentMember)
      ↓ householdId via ChangeNotifierProxyProvider
  ChoresProvider → fetchChores() + fetchDefaultChores()
  ShoppingProvider → fetchItems() + fetchFavorites()
  FinanceProvider → fetchAll() [debts + transactions + recurring]
```

**AppProvider** ([`app_provider.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/providers/app_provider.dart)) — owns `Household` and `currentMember`. Persists the selected member in `SharedPreferences` ([`app_provider.dart:31`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/providers/app_provider.dart#L31)). Auto-selects if only one member exists; shows the identity picker if multiple members and none saved.

---

## API Client

Source: [`frontend/lib/core/api_client.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/core/api_client.dart)

Singleton `Dio` with two interceptors:

- **`_ApiLogInterceptor`** — increments `apiInFlight` (a `ValueNotifier<int>`) on each request start/end. The nav shell watches this to show/hide a 2px progress bar at the top of every screen. On mutating responses (POST/PUT/DELETE), emits to `apiSuccessEvents` broadcast stream — the shell shows success snackbars. Logs request+response with timing in debug mode.
- **Error interceptor** — wraps Dio errors into `ApiException` with the JSON `detail` message extracted.

Timeouts: 45 s connect, 30 s receive ([`api_client.dart:39`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/core/api_client.dart#L39)).

---

## Navigation Shell

Source: [`app.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/app.dart)

Before rendering the main scaffold, three states are handled in order:

1. **Wake-up screen** — loading + no household yet → spinner + "Connecting…"
2. **Error screen** — API failed → troubleshooting checklist + Retry button
3. **Identity picker** — household loaded, no `currentMember`, multiple members → "Who are you?" full-screen

Main scaffold uses `IndexedStack` ([`app.dart:182`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/app.dart#L182)) so all three tab navigators exist simultaneously — tab state and scroll position are preserved when switching.

> **Recording:** [Add member](gifs/01-add-member.mp4)

---

## Chores Module

**ChoresScreen** ([`chores_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/chores/chores_screen.dart)) — Filters chores into four sections client-side: Your tasks, Others' tasks, Unassigned, Completed. Cards in "Your tasks" show an age-based border: grey → orange at 2 days → red at 3+ days ([`chores_screen.dart:116`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/chores/chores_screen.dart#L116)). "Take Over" reassigns `assigned_to`; completed cards show "Originally: [name]" when the completer differs from the original assignee.

> **Recording:** [Complete chore](gifs/04-complete-chore.mp4)

**AddChoreScreen** ([`add_chore_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/chores/add_chore_screen.dart)) — `SegmentedButton` toggles between Immediate (name + member → `POST /chores/`) and Scheduled (name + member + frequency + start date → `POST /default-chores/`). Both default the assignee to `currentMember` ([`add_chore_screen.dart:33`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/chores/add_chore_screen.dart#L33)).

> **Recording:** [Add chore](gifs/02-add-chore.mp4) · [Scheduled chore](gifs/03-add-scheduled-chore.mp4)

**StatsScreen** ([`stats_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/chores/stats_screen.dart)) — Three `fl_chart` charts: weekly line chart (x-axis: ISO week label), pie chart (original vs taken-over), daily bar chart (last 7 days, labeled by weekday abbreviation).


---

## Shopping Module

**ShoppingScreen** ([`shopping_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/shopping/shopping_screen.dart)) — Items sorted unpurchased-first. Pull-to-refresh. `hideChecked` toggle filters the list. Purchasing a debt-linked item shows a price dialog, calls `FinanceProvider.addTransaction`, then links the resulting transaction to the item ([`shopping_screen.dart:105`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/shopping/shopping_screen.dart#L105)). Participant list: `single` → current member + item creator; `group` → all members.

> **Recording:** [Shopping list](gifs/07-shopping-list.mp4)

**AddItemScreen** ([`add_item_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/shopping/add_item_screen.dart)) — Batch submission: type multiple items, select favorites by quantity, one `POST /shopping-items/` with a JSON array. Debt toggle and split mode apply to the whole batch.

**ShoppingSettingsScreen** ([`shopping_settings_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/shopping/shopping_settings_screen.dart)) — Toggles for avatar visibility and hide-purchased (in-memory only, not persisted). Favorites CRUD with Edit mode.

---

## Finance Module

**FinanceScreen** ([`finance_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/finance/finance_screen.dart)) — Overview: aggregated debts, next scheduled payment, 3 most recent transactions. Pull-to-refresh. Tap a debt row → `_SettleSheet` bottom sheet with Full / Partial chips. Partial shows an amount field → `POST /debts/settle/`.

> **Recording:** [Add transaction](gifs/05-add-transaction.mp4) · [Settle debt](gifs/06-settle-debt.mp4)

**TransactionFormScreen** ([`transaction_form_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/finance/transaction_form_screen.dart)) — Create and edit. Defaults creditor to `currentMember`, all members as participants. Creditor selected via opacity-dimmed avatar row. Live per-person share calculation. Scheduled toggle shows date picker + recurrence bottom sheet (`weekly / biweekly / monthly / semiannually`).

**TransactionsScreen** ([`transactions_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/finance/transactions_screen.dart)) — Full history grouped by month (`DateFormat('MMMM yyyy')`), running total in app bar. Tap → detail sheet with Edit (checks `can-edit` first) and Delete.

**ScheduledPaymentsScreen** ([`scheduled_payments_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/finance/scheduled_payments_screen.dart)) — Recurring templates grouped by `next_payment_date` month. Tap → detail sheet with Edit / Delete.

---

## Shared Widgets

| Widget | Purpose |
|---|---|
| `AppHeader` | App bar with hamburger, title, subtitle, member avatar |
| `MemberAvatar` | Colored circle with initials |
| `EmptyState` | Centered icon + message for empty lists |
| `LoadingSpinner` | Centered `CircularProgressIndicator` |
