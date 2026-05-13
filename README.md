# Hermes Manager

Mobile AI chat application with multi-user group chat and multi-agent collaboration support.

## Architecture

```
┌─────────────────────┐     ┌──────────────────────┐
│    Flutter App      │────▶│   Hermes Server       │
│   (Mobile Client)   │◀────│   (FastAPI Backend)   │
└─────────────────────┘     └──────────┬───────────┘
                           WebSocket/REST│
                                        ▼
                            ┌──────────────────────┐
                            │   Hermes Gateway      │
                            │   (AI Agent Router)   │
                            └──────────────────────┘
```

## Projects

| Project | Description | Tech Stack |
|---------|-------------|------------|
| [hermes-server](./hermes-server/) | Backend API Server | Python, FastAPI, SQLAlchemy, WebSocket |
| [hermes-app](./hermes-app/) | Mobile App (Flutter) | Flutter, Riverpod, dio |

## Features

- **Multi-user Authentication** - JWT-based auth with access/refresh tokens
- **Group Chat** - WeChat-style messaging with rooms and invite codes
- **Multi-Agent Collaboration** - Support for multiple AI agents in chats
  - Broadcast mode - all agents respond
  - Mention mode - @mention specific agents
  - Router mode - intelligent routing
- **Machine Management** - Connect and manage multiple machines running agents
- **Agent Management** - Configure and control AI agents across machines

## Quick Start

### Backend (Docker)

```bash
cd hermes-server

# Development
docker compose up --build

# Production (with volume mount)
docker compose -f docker-compose.prod.yml up --build -d
```

The server runs on `http://localhost:3002`. API docs available at `/docs`.

### Backend (Local Development)

```bash
cd hermes-server
pip install -r requirements.txt
uvicorn app.main:app --reload --port 3002
```

### Mobile App

```bash
cd hermes-app
flutter pub get
flutter run
```

## Environment Variables

Create `.env` from `.env.example`:

```bash
cp .env.example .env
```

| Variable | Description | Default |
|----------|-------------|---------|
| `JWT_SECRET_KEY` | JWT signing key | `your-secret-key-change-in-production` |
| `DEBUG` | Debug mode | `false` |
| `DATABASE_URL` | SQLite database URL | `sqlite+aiosqlite:///./data/hermes.db` |

## API Documentation

After starting the server, visit:
- Swagger UI: `http://localhost:3002/docs`
- ReDoc: `http://localhost:3002/redoc`

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/register` | User registration |
| POST | `/auth/login` | User login |
| GET | `/rooms` | List chat rooms |
| POST | `/rooms` | Create chat room |
| GET | `/rooms/{id}/messages` | Get room messages |
| WS | `/ws/chat` | WebSocket chat |
| GET | `/machines` | List machines |
| POST | `/machines` | Add machine |
| GET | `/agents` | List agents |

## Database

SQLite database is stored at `/vol1/1000/nas1/docker/hermes-server/hermes.db` when running via Docker Compose with production configuration.

## License

MIT
