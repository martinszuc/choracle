# Frontend

Flutter Android app. UI follows Material 3. State is managed with the `provider` package using `ChangeNotifier`. No local database — all state comes from the REST API and lives in memory.

---

## Provider Architecture

Source: [`frontend/lib/app.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/app.dart)

Four providers, set up in `app.dart` via `MultiProvider`:

```dart
MultiProvider(providers: [
  ChangeNotifierProvider(create: (_) => AppProvider()..initialize()),
  ChangeNotifierProxyProvider<AppProvider, ChoresProvider>(...),
  ChangeNotifierProxyProvider<AppProvider, ShoppingProvider>(...),
  ChangeNotifierProxyProvider<AppProvider, FinanceProvider>(...),
])
```

`ChangeNotifierProxyProvider` is the key pattern here ([`app.dart:25–35`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/app.dart#L25)). The three module providers depend on `AppProvider` to get the `householdId`. Whenever `AppProvider` rebuilds (e.g. after `initialize()` finishes), the proxy re-runs `update`, which calls `setHouseholdId()` on each child provider. This triggers their initial data fetch automatically — the screens never need to call `fetch` manually.

```
AppProvider (household, currentMember)
    │
    ├── ChoresProvider.setHouseholdId() → fetchChores() + fetchDefaultChores()
    ├── ShoppingProvider.setHouseholdId() → fetchItems() + fetchFavorites()
    └── FinanceProvider.setHouseholdId() → fetchAll()   (debts + transactions + recurring)
```

### AppProvider
[`frontend/lib/providers/app_provider.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/providers/app_provider.dart)

Owns the `Household` (members list) and `currentMember` (which member is "me"). Persists `currentMember` selection across app restarts via `SharedPreferences` ([`app_provider.dart:31–33`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/providers/app_provider.dart#L31)):

```dart
final savedId = prefs.getString(_kSelectedMemberId);
if (savedId != null) {
  _currentMember = _household!.members.where((m) => m.id == savedId).firstOrNull;
}
```

If a single member exists and none is saved, it auto-selects. With multiple members and no saved choice, the identity picker screen is shown.

---

## API Client

Source: [`frontend/lib/core/api_client.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/core/api_client.dart)

Singleton `Dio` instance with two interceptors:

**`_ApiLogInterceptor`** — the more interesting one ([`api_client.dart:71`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/core/api_client.dart#L71)):
- On every request start: increments `apiInFlight` (a `ValueNotifier<int>`) — the navigation shell watches this to show/hide the thin progress bar at the top of every screen.
- On every mutating response (POST/PUT/DELETE): emits a short string (`"Saved"`, `"Updated"`, `"Deleted"`) into `apiSuccessEvents` — a broadcast `StreamController` the shell listens to for success snackbars.
- Logs request + response body (truncated at 800 chars) in debug mode with timing.

**Error interceptor** — wraps Dio errors into `ApiException` with a clean `message`, extracted from the JSON `detail` field ([`api_client.dart:46–60`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/core/api_client.dart#L46)).

Timeouts are set generously: 45 s connect, 30 s receive ([`api_client.dart:39–41`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/core/api_client.dart#L39)). This is intentional — the local server won't need it, but a Render cold start can take 20–30 s.

---

## Navigation Shell

Source: [`frontend/lib/app.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/app.dart)

The shell (`_HomeShell`) has three layers of logic before rendering the main `Scaffold`:

1. **Wake-up screen** ([`app.dart:121–123`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/app.dart#L121)) — shown while `AppProvider` is loading and household is `null`. Displays "Connecting…" with a spinner.
2. **Error screen** ([`app.dart:125–130`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/app.dart#L125)) — if the API call fails entirely, shows a troubleshooting checklist with a Retry button.
3. **Identity picker** ([`app.dart:134–136`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/app.dart#L134)) — if household loaded but `currentMember` is `null` and there are multiple members, shows a full-screen "Who are you?" picker.

The main Scaffold uses `IndexedStack` for tabs ([`app.dart:182`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/app.dart#L182)) — all three tab navigators exist simultaneously, preserving scroll position and state when switching tabs.

The progress bar overlay ([`app.dart:200–209`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/app.dart#L200)) is a `Positioned` `LinearProgressIndicator` at the top of the stack, shown whenever `apiInFlight.value > 0`:

```dart
ValueListenableBuilder<int>(
  valueListenable: apiInFlight,
  builder: (_, count, __) => count > 0
    ? const Positioned(top: 0, ..., child: LinearProgressIndicator(minHeight: 2))
    : const SizedBox.shrink(),
)
```

> **GIF:** `gifs/01-launch.gif` — Launch app → spinner → identity picker → tap name → main screen appears

---

## Chores Module

### ChoresScreen
[`frontend/lib/screens/chores/chores_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/chores/chores_screen.dart)

Chores are filtered client-side into four buckets ([`chores_screen.dart:27–36`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/chores/chores_screen.dart#L27)):
- **Your tasks** — `assigned_to.id == currentMember.id && !completed`
- **Others' tasks** — different member, not completed
- **Unassigned** — `assigned_to == null`, not completed
- **Completed this week** — all completed chores

Cards in "Your tasks" show an age-based border color ([`chores_screen.dart:116–121`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/chores/chores_screen.dart#L116)): grey under 2 days, orange at 2 days, red at 3+ days — a visual urgency indicator without any explicit deadline field.

"Take Over" calls `PUT /chores/{id}/assign/` and the backend stores which member originally had it. The completed card shows "Originally: [name]" when the completer was not the original assignee ([`chores_screen.dart:177–180`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/chores/chores_screen.dart#L177)).

> **GIF:** `gifs/02-chores.gif` — Scroll sections, tap Done on own chore, tap Take Over on another's

### AddChoreScreen
[`frontend/lib/screens/chores/add_chore_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/chores/add_chore_screen.dart)

Two modes via `SegmentedButton`:

- **Immediate** — name + member dropdown → `POST /chores/`. Defaults assignee to `currentMember` ([`add_chore_screen.dart:33–35`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/chores/add_chore_screen.dart#L33)).
- **Scheduled** — name + member + frequency (days) + start date → `POST /default-chores/`. Below the form, lists existing templates with a delete button. The scheduler picks these up at midnight.

> **GIF:** `gifs/03-add-chore.gif` — Switch Immediate↔Scheduled, set frequency + date picker, save template

### StatsScreen
[`frontend/lib/screens/chores/stats_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/chores/stats_screen.dart)

Three charts from `fl_chart`:

- **Line chart (`_WeeklyChart`)** — x-axis is ISO week keys sorted chronologically. The label is `sorted[i].key.substring(5)` which trims `"2026-"` leaving `"W17"` ([`stats_screen.dart:109`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/chores/stats_screen.dart#L109)).
- **Pie chart (`_PieChart`)** — original completions vs taken-over, derived as `completedCount - takenOverCount`.
- **Bar chart (`_DailyChart`)** — last 7 days, x-axis labeled with day abbreviation (`Mon`, `Tue`, …). Data comes from `MemberStats.daily_history` keyed by ISO date string.

> **GIF:** `gifs/04-stats.gif` — Open stats from chores header icon, scroll charts

---

## Shopping Module

### ShoppingScreen
[`frontend/lib/screens/shopping/shopping_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/shopping/shopping_screen.dart)

Items are sorted: unpurchased first (by `createdAt`), purchased last. Pull-to-refresh calls `fetchItems()`. The "Hide purchased" toggle (`ShoppingProvider.hideChecked`) filters the list before rendering.

Checking an item calls `_handlePurchase` ([`shopping_screen.dart:105`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/shopping/shopping_screen.dart#L105)):
- If `debt_option == 'none'` → immediately marks purchased, no dialog.
- If `debt_option == 'single'` or `'group'` → shows a price dialog, creates a `Transaction` via `FinanceProvider.addTransaction`, then links it to the item via `ShoppingProvider.togglePurchased(..., linkedTransactionId: txId)`.

The participant list for the auto-created transaction:
- `'single'` → `[currentMember.id, item.createdBy.id]`
- `'group'` → all household member IDs

> **GIF:** `gifs/05-shopping.gif` — Add item by typing, add from favorites with qty, submit list  
> **GIF:** `gifs/06-purchase.gif` — Tick a debt-linked item → price dialog → confirm → debt row appears in Finance

### AddItemScreen
[`frontend/lib/screens/shopping/add_item_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/shopping/add_item_screen.dart)

Batch submission — the user can type multiple items and adjust quantities before a single `POST /shopping-items/` with a JSON array. Favorites are shown below with +/− quantity controls; qty of 0 means excluded. The debt toggle and split mode (person/group) apply uniformly to the whole batch.

### ShoppingSettingsScreen
[`frontend/lib/screens/shopping/shopping_settings_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/shopping/shopping_settings_screen.dart)

Two in-memory toggles (not persisted to backend or SharedPreferences — reset on app restart):
- Show member avatars
- Hide purchased items

Favorites CRUD: add by typing, delete via Edit mode toggle (shows red delete icons).

---

## Finance Module

### FinanceScreen
[`frontend/lib/screens/finance/finance_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/finance/finance_screen.dart)

The overview screen shows three sections: active debts, next scheduled payment, and the 3 most recent transactions. Has pull-to-refresh.

Tapping a debt row opens `_SettleSheet` — a bottom sheet with "Full" / "Partial" chip selection ([`finance_screen.dart:135`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/finance/finance_screen.dart#L135)). Partial mode shows an amount field. On confirm → `POST /debts/settle/` → all existing debt rows between the pair are deleted and a settlement Transaction is created.

> **GIF:** `gifs/07-finance.gif` — View debt row, tap → settle sheet, choose partial, enter amount, confirm  
> **GIF:** `gifs/08-settle.gif` — Full settlement: tap debt → Full → Settle → row disappears

### TransactionFormScreen
[`frontend/lib/screens/finance/transaction_form_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/finance/transaction_form_screen.dart)

Used for both creating and editing transactions (`existing` param). On create, defaults creditor to `currentMember` and pre-selects all members as participants ([`transaction_form_screen.dart:43–45`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/finance/transaction_form_screen.dart#L43)).

Creditor selection is a row of avatar+name tiles with opacity — selected member is full opacity, others at 40%. Participants are checkboxes with a live per-person share calculation.

"Shared shopping items" button ([`transaction_form_screen.dart:126–133`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/finance/transaction_form_screen.dart#L126)) pulls group-debt unpurchased items and lets the user pick them to pre-fill the description.

The `_recurrenceOptions` list ([`transaction_form_screen.dart:11`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/finance/transaction_form_screen.dart#L11)) is `['weekly', 'biweekly', 'monthly', 'semiannually']` — presented in a bottom sheet picker when the scheduled toggle is enabled.

### TransactionsScreen
[`frontend/lib/screens/finance/transactions_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/finance/transactions_screen.dart)

Full history, grouped by month ([`transactions_screen.dart:59–66`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/finance/transactions_screen.dart#L59)) using `DateFormat('MMMM yyyy')`. Shows running total in the app bar subtitle. Tapping a row opens `_TxDetailSheet` with amount, creditor, date, and Edit/Delete buttons. Edit checks `can-edit` before navigating.

### ScheduledPaymentsScreen
[`frontend/lib/screens/finance/scheduled_payments_screen.dart`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/screens/finance/scheduled_payments_screen.dart)

Lists recurring transaction templates grouped by their `next_payment_date` month. Each tile shows the next date and recurrence interval. Tap → detail sheet with Edit/Delete.

---

## Shared Widgets

| Widget | File | Purpose |
|---|---|---|
| `AppHeader` | `widgets/shared/app_header.dart` | Consistent app bar with hamburger menu trigger, title, subtitle, current member avatar |
| `MemberAvatar` | `widgets/shared/member_avatar.dart` | Colored circle with initials, used everywhere |
| `EmptyState` | `widgets/shared/empty_state.dart` | Centered icon + message for empty lists |
| `LoadingSpinner` | `widgets/shared/loading_spinner.dart` | Centered `CircularProgressIndicator` |
