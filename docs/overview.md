# Choracle — Project Overview

**Course:** XPC-MMA Final Project  
**Author:** Martin Szuc (231284)

Choracle is a shared household management app for Android. It covers three domains in one place: chore tracking, a shared shopping list, and shared expense management. The app is designed for a fixed household — a single household with named members — rather than multi-tenant accounts.

---

## Tech Stack

| Layer | Technology | Notes |
|---|---|---|
| Frontend | Flutter 3 (Android) | Dart, Provider, Dio |
| Backend | Django 4 + Django REST Framework | Python, function-based views |
| Database | PostgreSQL | Single-household schema |
| Scheduler | APScheduler + django-apscheduler | Nightly cron at midnight |
| HTTP Client | Dio | Singleton, custom interceptors |
| State Management | Provider (`ChangeNotifier`) | `ChangeNotifierProxyProvider` for dependencies |
| Deployment | Local (primary) / Render.com (secondary) | See [Running the app](#running-the-app) |

---

## System Architecture

> **Diagram:** Recreate in draw.io. Simple three-box vertical layout.

```
┌─────────────────────────────────────────────┐
│           Flutter App (Android)              │
│                                             │
│  ┌──────────────┐   ┌─────────────────────┐ │
│  │   Provider   │   │    Dio HTTP Client   │ │
│  │    Layer     │◄──│  + Log Interceptor   │ │
│  │              │   │  + Error Interceptor  │ │
│  └──────────────┘   └──────────┬───────────┘ │
└─────────────────────────────────┼────────────┘
                                  │  REST API (HTTP/HTTPS)
                         ┌────────▼──────────┐
                         │   Django Backend   │
                         │                   │
                         │  ┌─────────────┐  │
                         │  │ DRF Views   │  │
                         │  └──────┬──────┘  │
                         │  ┌──────▼──────┐  │
                         │  │ APScheduler │  │
                         │  │ (midnight)  │  │
                         │  └─────────────┘  │
                         │  ┌─────────────┐  │
                         │  │  PostgreSQL  │  │
                         │  └─────────────┘  │
                         └───────────────────┘
```

**Data flow:** Flutter providers call `ApiClient` → Dio serializes the request → Django view processes it, hits the DB → JSON response → provider updates state → UI rebuilds via `notifyListeners()`.

The scheduler runs as a background thread inside the same Django process, triggered by APScheduler's `DjangoJobStore` at midnight each day.

---

## Data Model

> **Diagram:** Recreate as ER diagram in draw.io. Use crow's foot notation.

```
Household ──────< Member
    │                │
    │                └──────────────────┐
    │                                   │
    ├──< Chore ─────────── assigned_to ─┤
    │         └──────── completed_by ───┤
    │         └─── original_assigned_to ┤
    │                                   │
    ├──< DefaultChore ── assigned_to ───┤
    │                                   │
    ├──< MemberStats ─── member ────────┤ (1:1)
    │                                   │
    ├──< ShoppingItem ── created_by ────┤
    │           └── linked_transaction ─┐
    │                                   │
    ├──< Transaction ── creditor ───────┤
    │         └──>< participants (M2M) ─┤
    │                                   │
    └──< Debt ─────── creditor ─────────┤
              └───── debtor ────────────┘
              └── related_transaction ──┘
```

Key design choices:
- `Chore` stores both `assigned_to` (current holder) and `original_assigned_to` (who it started with) — used to detect and count take-overs.
- `MemberStats.weekly_history` and `daily_history` are `JSONField` dicts keyed by ISO week string (`"2026-W17"`) and date string (`"2026-04-27"`). The backend increments them on each chore completion — no JOIN needed for stats queries.
- `Debt` rows are created by `_spawn_transaction_debts` ([`views.py:40`](https://github.com/martinszuc/choracle/blob/main/backend/api/views.py#L40)) — one `Debt` per non-creditor participant, each for their equal share.

---

## Running the App

### 1. Start the backend (primary)

```bash
cd backend
source venv/bin/activate
python manage.py runserver
```

The server starts at `http://127.0.0.1:8000/`.

### 2. Run the Flutter app

**Android emulator** (emulator maps `10.0.2.2` to the host machine's `localhost`):
```bash
cd frontend
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

**Physical device** (replace with your machine's LAN IP — find it with `ipconfig getifaddr en0`):
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000/api
```

**Default (no flag):** falls back to the Render deployment at `https://choracle-backend.onrender.com/api`. Note: Render free tier spins down after inactivity — first request takes 20–30 s.

The base URL is injected at compile time via `--dart-define` and read in [`constants.dart:1`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/core/constants.dart#L1):
```dart
const String kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://choracle-backend.onrender.com/api',
);
```

### First-time setup

```bash
cd backend
python manage.py migrate
python manage.py seed_household   # creates household + sample members
```

---

## App GIFs

> Record these short clips (5–15 s each) and save to `docs/gifs/`. Use Android screen recorder or `scrcpy`.

| File | What to record |
|---|---|
| `gifs/01-launch.gif` | Cold launch → wake-up spinner → identity picker → main screen |
| `gifs/02-chores.gif` | Chores screen: complete own chore, take over another member's chore |
| `gifs/03-add-chore.gif` | Add chore: type name, switch Immediate↔Scheduled, set frequency + date |
| `gifs/04-stats.gif` | Stats screen: scroll through line chart, pie chart, bar chart |
| `gifs/05-shopping.gif` | Add items from typed input + favorites, toggle qty, submit |
| `gifs/06-purchase.gif` | Check off a debt-linked item → price dialog → debt created |
| `gifs/07-finance.gif` | Finance screen: add transaction with participants, debt appears |
| `gifs/08-settle.gif` | Tap a debt row → settle modal → choose full or partial |

---

## Project Structure

```
choracle/
├── backend/
│   ├── api/
│   │   ├── models.py          # all data models
│   │   ├── views.py           # function-based API views
│   │   ├── serializers.py     # DRF serializers
│   │   ├── scheduler.py       # APScheduler jobs
│   │   └── urls.py            # URL routing
│   └── choracle/
│       └── settings.py
├── frontend/
│   └── lib/
│       ├── main.dart
│       ├── app.dart            # root widget, provider setup, nav shell
│       ├── core/
│       │   ├── api_client.dart # Dio singleton + interceptors
│       │   └── constants.dart  # kBaseUrl
│       ├── models/             # Dart data classes (fromJson)
│       ├── providers/          # ChangeNotifier state
│       └── screens/
│           ├── chores/
│           ├── shopping/
│           └── finance/
└── docs/                       # ← you are here
```
