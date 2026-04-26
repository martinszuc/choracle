# Choracle

A household management app for people living together. Choracle keeps shared chores, shopping, and expenses in one place.

## Features

**Chores**
- One-time and recurring task management
- Weekly task tracking per household member
- Take over tasks from other members
- Completion statistics with charts

**Shopping List**
- Shared list with quantity tracking
- Household favorites for quick adding
- Automatic debt creation on purchase

**Finance**
- Shared expense tracking and debt management
- Recurring payment scheduling
- Full and partial debt settlements

## Tech Stack

- **Frontend:** Flutter (Android)
- **Backend:** Django REST Framework
- **Database:** PostgreSQL
- **Deployment:** Render (free tier)

---

## Live Backend

**URL:** `https://choracle-backend.onrender.com`

> **Free tier note:** The backend spins down after ~15 minutes of inactivity.
> The first request after idle takes **20–30 seconds** to wake up. Subsequent
> requests are instant. If the app appears stuck on load, wait a moment and
> pull-to-refresh.

To manually wake it before opening the app:

```bash
curl https://choracle-backend.onrender.com/api/household/
```

### Database

- **Provider:** Render PostgreSQL (free tier)
- **Expires:** 2026-05-25 — must be upgraded or recreated before that date or all data is lost.

To seed the initial household after a fresh database:

```bash
# SSH into the Render shell or run via Render dashboard → Shell
python manage.py seed_household
```

### Verified endpoints (2026-04-26)

| Method | Path | Status |
|--------|------|--------|
| GET | `/api/household/` | ✓ 200 |
| GET | `/api/chores/` | ✓ 200 |
| GET | `/api/default-chores/` | ✓ 200 |
| GET | `/api/shopping-items/` | ✓ 200 |
| GET | `/api/favorite-items/` | ✓ 200 |
| GET | `/api/transactions/` | ✓ 200 |
| GET | `/api/transactions/recurring/` | ✓ 200 |
| GET | `/api/debts/` | ✓ 200 |

---

## Development Setup

### Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # fill in your values
python manage.py migrate
python manage.py seed_household   # creates the single household + sample members
python manage.py runserver
```

### Frontend

```bash
cd frontend
flutter pub get

# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api

# Physical device (replace with your machine's LAN IP)
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000/api

# Against the live Render backend (default, no flag needed)
flutter run
```

---

## Deployment

Backend is deployed on Render. See `render.yaml` for the full config.

### Render environment variables

| Key | Value |
|-----|-------|
| `SECRET_KEY` | auto-generated |
| `DEBUG` | `False` |
| `DATABASE_URL` | from Render Postgres |
| `ALLOWED_HOSTS` | `.onrender.com` |
| `CORS_ALLOWED_ORIGINS` | `*` |

### Re-deploying

Push to `main` — Render auto-deploys on every push to the connected branch.

```bash
git push origin main
```

---

*Forked from [HouseUP](https://github.com/RomanPoliacik/houseup)*
