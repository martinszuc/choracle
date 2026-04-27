# Choracle — Project Overview

**Course:** XPC-MMA Final Project · Martin Szuc (231284)

Shared household management app for Android — chore tracking, shopping list, and expense management in one place. Targets a single fixed household with named members. No authentication.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter 3 (Android) — Provider, Dio |
| Backend | Django 4 + Django REST Framework |
| Database | PostgreSQL |
| Scheduler | APScheduler + django-apscheduler |
| Deployment | Local (primary) / Render.com (secondary) |

---

## System Architecture

> Recreate in draw.io: three boxes (Flutter app, Django + APScheduler, PostgreSQL) connected by arrows. Add a "midnight cron" callout on the scheduler.

```
┌──────────────────────────────────┐
│      Flutter App (Android)       │
│   Provider Layer ← Dio Client    │
└─────────────────┬────────────────┘
                  │ REST API
         ┌────────▼──────────┐
         │   Django Backend  │
         │  DRF Views        │
         │  APScheduler      │
         │  PostgreSQL       │
         └───────────────────┘
```

---

## Data Model

> Recreate as ER diagram in draw.io using crow's foot notation.

```
Household ──< Member
    ├──< Chore (assigned_to, original_assigned_to, completed_by → Member)
    ├──< DefaultChore (assigned_to → Member)
    ├──< MemberStats (1:1 → Member)
    ├──< ShoppingItem (created_by → Member, linked_transaction → Transaction)
    ├──< Transaction (creditor → Member, participants M2M → Member)
    └──< Debt (creditor, debtor → Member, related_transaction → Transaction)
```

Notable: `Chore` stores both `assigned_to` and `original_assigned_to` — the delta is how take-overs are detected. `MemberStats` uses JSON dicts for weekly/daily history, incremented in-place on each completion.

---

## Running the App

### 1. Start the backend

```bash
cd backend
source venv/bin/activate
python manage.py runserver
```

### 2. Run Flutter

**Emulator** (`10.0.2.2` maps to the host's localhost):
```bash
cd frontend
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

**Physical device** (find your LAN IP with `ipconfig getifaddr en0`):
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000/api
```

**No flag** → falls back to the Render deployment (free tier, first request takes ~30 s to wake up).

The base URL is injected at compile time via `--dart-define` — [`constants.dart:1`](https://github.com/martinszuc/choracle/blob/main/frontend/lib/core/constants.dart#L1).

### First-time setup

```bash
python manage.py migrate
python manage.py seed_household
```

---

## GIF Recordings

> Save to `docs/gifs/`. Use Android screen recorder or `scrcpy`.

| File | What to record |
|---|---|
| `gifs/01-launch.gif` | Cold launch → spinner → identity picker → main screen |
| `gifs/02-chores.gif` | Complete own chore + take over another member's chore |
| `gifs/03-add-chore.gif` | Add immediate chore + switch to scheduled, set frequency + date |
| `gifs/04-stats.gif` | Open stats, scroll through the three charts |
| `gifs/05-shopping.gif` | Add items (typed + favorites), adjust qty, submit |
| `gifs/06-purchase.gif` | Purchase a debt-linked item → price dialog → debt created |
| `gifs/07-finance.gif` | Add transaction with participants, debt row appears |
| `gifs/08-settle.gif` | Tap debt → settle sheet → partial settlement |

---

## Project Structure

```
choracle/
├── backend/
│   └── api/
│       ├── models.py        # all data models
│       ├── views.py         # function-based API views
│       ├── serializers.py
│       ├── scheduler.py     # APScheduler jobs
│       └── urls.py
├── frontend/
│   └── lib/
│       ├── app.dart         # root widget, provider setup, nav shell
│       ├── core/
│       │   ├── api_client.dart
│       │   └── constants.dart
│       ├── models/
│       ├── providers/
│       └── screens/
│           ├── chores/
│           ├── shopping/
│           └── finance/
└── docs/
```
