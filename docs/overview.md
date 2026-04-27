# Choracle — Project Overview

**Course:** XPC-MMA Final Project · Martin Szuc (231284)

Shared household management app for Android — chore tracking, shopping list, and expense management in one place. Targets a single fixed household with named members. No authentication.

| | |
|---|---|
| **Demo video** | [YouTube Short](https://youtube.com/shorts/p1JijENZFTk?feature=share) |
| **Presentation** | [Google Slides](https://docs.google.com/presentation/d/1jWutQJZBuhMMU7x55qPtToyb9j81pP7IZmwUseL6kx4/edit?usp=sharing) |

---

## Work Packages

| WP | Title | Estimated hours |
|---|---|---|
| WP1 | Backend — Django REST API | 12 h |
| WP2 | Chores Module | 10 h |
| WP3 | Shopping List Module | 10 h |
| WP4 | Finance Module | 14 h |
| WP5 | Presentation & Demo | 15 min |

**WP1** — Django models (Household, Member, Chore, DefaultChore, MemberStats, ShoppingItem, Transaction, Debt), DRF serializers and views, CORS, APScheduler nightly jobs, Render deployment.

**WP2** — Weekly chore screen (Your tasks / Others' / Unassigned / Completed), take-over flow, immediate + scheduled chore creation, stats screen with three fl_chart charts.

**WP3** — Shared shopping list, batch item add, household favorites, debt-linking on purchase (single / group split), UI settings (hide purchased, toggle avatars).

**WP4** — Transaction CRUD with creditor + participants + amount, recurring payment templates, debt aggregation (GROUP BY + SUM), full and partial settlement, transaction history grouped by month.

**WP5** — 10 min presentation + 3 min recorded demo + 2 min Q&A.

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

## Screenshots

| Chores | Shopping | Finance | Error |
|---|---|---|---|
| ![Chores](screens/screen_chores.jpg) | ![Shopping](screens/screen_shopping.jpg) | ![Finance](screens/screen_finance.jpg) | ![Error](screens/screen_no_connection_to_server.jpg) |

**Chores** — Weekly tasks split into Your tasks, Others' tasks, and Completed. "Done" completes your own chore; "Take Over" reassigns another member's chore to you.

**Shopping** — Shared list with checkbox purchase flow. Purchased items shown with strikethrough. Avatar shows who added each item.

**Finance** — Aggregated debt rows (debtor → amount → creditor), upcoming scheduled payments, and recent transaction history.

**Error screen** — Shown when the backend is unreachable. Includes a troubleshooting checklist and Retry button.

---

## Recordings

### Add member

<video src="gifs/01-add-member.mp4" controls width="320"></video>

Add a new household member via the sidebar drawer. Color is auto-generated from the name.

---

### Add immediate chore

<video src="gifs/02-add-chore.mp4" controls width="320"></video>

Create a one-time chore and assign it to a member. Defaults to the current user.

---

### Add scheduled chore

<video src="gifs/03-add-scheduled-chore.mp4" controls width="320"></video>

Create a recurring chore template with frequency and start date. The first instance is generated immediately if start date is today or in the past; subsequent ones fire nightly.

---

### Complete a chore

<video src="gifs/04-complete-chore.mp4" controls width="320"></video>

Mark your own chore as done. Completed chores move to the "Completed this week" section with a strikethrough.

---

### Add a transaction

<video src="gifs/05-add-transaction.mp4" controls width="320"></video>

Add a shared expense — select creditor, participants, and amount. Debt rows are created automatically and split equally.

---

### Settle a debt

<video src="gifs/06-settle-debt.mp4" controls width="320"></video>

Tap a debt row to open the settle sheet. Choose full or partial settlement. Partial leaves a remainder debt.

---

### Shopping list

<video src="gifs/07-shopping-list.mp4" controls width="320"></video>

Add items by typing or from favorites. Check off items to mark as purchased.

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
