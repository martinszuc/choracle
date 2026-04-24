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
- **Deployment:** Render

## Development Setup

### Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # fill in your values
python manage.py migrate
python manage.py runserver
```

### Frontend

```bash
cd frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

For physical device, replace `10.0.2.2` with your machine's LAN IP.

## Deployment

Backend is deployed on Render. See `render.yaml` for configuration.

---

*Forked from [HouseUP](https://github.com/RomanPoliacik/houseup)*