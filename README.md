# Choracle — Shared Household Manager

**XPC-MMA Final Project · Martin Szuc (231284)**

A multi-user household management app for Android. Covers chore tracking, a shared shopping list, and shared expense management in one place.

---

## Links

| | |
|---|---|
| **Demo video** | [YouTube Short](https://youtube.com/shorts/p1JijENZFTk?feature=share) |
| **Presentation** | [Google Slides](https://docs.google.com/presentation/d/1jWutQJZBuhMMU7x55qPtToyb9j81pP7IZmwUseL6kx4/edit?usp=sharing) |
| **Overview** | [docs/overview.md](docs/overview.md) — architecture, data model, setup |
| **Backend** | [docs/backend.md](docs/backend.md) — models, endpoints, scheduler |
| **Frontend** | [docs/frontend.md](docs/frontend.md) — state management, screens |

---

## Screenshots

| Chores | Shopping | Finance |
|---|---|---|
| ![Chores](docs/screens/screen_chores.jpg) | ![Shopping](docs/screens/screen_shopping.jpg) | ![Finance](docs/screens/screen_finance.jpg) |

---

## Work Packages

| WP | Title | Hours |
|---|---|---|
| WP1 | Backend — Django REST API | 12 h |
| WP2 | Chores Module | 10 h |
| WP3 | Shopping List Module | 10 h |
| WP4 | Finance Module | 14 h |
| WP5 | Presentation & Demo | 15 min |

**WP1 — Backend** · Django REST Framework, PostgreSQL, APScheduler. All CRUD endpoints, CORS, nightly scheduler for recurring chores and transactions. Deployed on Render.

**WP2 — Chores** · Weekly chore screen per member, take-over flow, immediate and scheduled (recurring) chore creation, completion stats with fl_chart charts.

**WP3 — Shopping** · Shared list, household favorites, debt-linking on purchase (single or group split), UI settings (hide purchased, toggle avatars).

**WP4 — Finance** · Transaction CRUD, recurring payment scheduling, debt aggregation, full and partial settlement. Full history grouped by month.

**WP5 — Presentation** · 10 min talk + 3 min demo (recorded) + 2 min Q&A.

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

## Features

**Chores**
- One-time and recurring task management
- Weekly task tracking per household member
- Take over tasks from other members
- Completion statistics with charts

**Shopping List**
- Shared list with quantity tracking
- Household favorites for quick adding
- Automatic debt creation on purchase (single or group split)

**Finance**
- Shared expense tracking and debt management
- Recurring payment scheduling
- Full and partial debt settlements
- Transaction history grouped by month

---

## Running Locally

### Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_household
python manage.py runserver 0.0.0.0:8000
```

### Frontend

```bash
cd frontend
flutter pub get

# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api

# Physical device (replace with your LAN IP)
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000/api
```

Find your LAN IP: `ipconfig getifaddr en0`

---

## Documentation

- [Overview — architecture, data model, setup](docs/overview.md)
- [Backend — models, endpoints, scheduler](docs/backend.md)
- [Frontend — state management, screens](docs/frontend.md)
