# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hermes Manager is a mobile AI chat application with multi-user group chat and multi-agent collaboration. It consists of two main components:
- **hermes-server**: Python/FastAPI backend (in `hermes-server/`)
- **hermes-app**: Flutter mobile app (in `hermes-app/`)

The backend connects to Hermes Gateway for AI agent routing.

## Common Commands

### Backend (hermes-server)

```bash
# Install dependencies
cd hermes-server && pip install -r requirements.txt

# Run locally (port 3002)
uvicorn app.main:app --reload --port 3002

# Run tests
pytest hermes-server/tests/ -v

# Docker build and run
docker compose -f docker-compose.prod.yml up --build -d
```

### Mobile App (hermes-app)

```bash
cd hermes-app
flutter pub get
flutter run
```

## Architecture

### Backend Structure (`hermes-server/`)

```
hermes-server/
├── app/
│   ├── main.py          # FastAPI app entry, includes /health endpoint
│   ├── config.py        # Settings via pydantic-settings (SettingsConfigDict)
│   ├── database.py      # SQLAlchemy async setup
│   ├── api/             # Route handlers (auth, rooms, messages, machines, agents, ws)
│   ├── models/          # SQLAlchemy models (user, room, message, machine, agent)
│   ├── schemas/         # Pydantic request/response schemas
│   └── core/            # Security utilities (JWT)
├── tests/               # pytest tests
├── Dockerfile           # Production Docker image (python:3.11-slim)
├── Dockerfile.dev       # Development with hot reload
└── docker-compose.yml   # Local development compose
```

### Database

- SQLite with aiosqlite for async operations
- Database URL configured via `DATABASE_URL` env var
- Production mount: `/vol1/1000/nas1/docker/hermes-server:/app/data`

### API Design

- REST endpoints for CRUD operations
- WebSocket at `/ws/chat` for real-time messaging
- JWT authentication with access/refresh token pattern
- CORS configured to allow mobile app origins

### Mobile App Structure (`hermes-app/`)

Uses Flutter with Riverpod for state management, dio for HTTP, and go_router for navigation. The lib/ directory follows clean architecture with data/presentation/router separation.

## Key Dependencies

- **Backend**: fastapi, uvicorn, sqlalchemy[asyncio], pydantic>=2.7.0, pydantic-settings>=2.5.0, python-jose, passlib, websockets
- **App**: flutter_riverpod, dio, web_socket_channel, go_router, flutter_secure_storage

## Notes

- pydantic-settings uses `SettingsConfigDict` (not `ConfigDict`) for model_config
- Server runs on port 3002 in production (configured in docker-compose.prod.yml)
- API docs available at `/docs` when server is running

## Development Rules

- **Every code change must be tested and pass before committing/pushing.**
  - Backend changes: verify syntax (`python -c "from app.xxx import ..."`) and run relevant tests.
  - Frontend (Flutter): run `flutter analyze` on modified files and fix all errors/warnings.
  - Bug fixes: reproduce the issue, verify the fix works, then commit.
  - New features: manual smoke-test the relevant flow end-to-end before pushing.
  - Never skip testing by claiming "it should work" — verify it actually does.
