# habitflow-mobile

Greenfield iOS rewrite of HabitFlow as a personal habit tracker. 

**Stack:** Swift 6 + SwiftUI (iOS 17+) · Vapor (server-side Swift) · PostgreSQL + SwiftData · Gemini API

## Layout

```
habitflow-mobile/
├── api/              # Vapor server (Postgres, JWT auth)
├── ios/              # SwiftUI app (coming Day 3)
└── docs/prp/         # Phase plans (see PRP-001)
```

The full Phase 1 plan lives at [`docs/prp/PRP-001-phase1-mobile-foundation.md`](docs/prp/PRP-001-phase1-mobile-foundation.md).

## Backend — running locally

Prereqs: Swift 6, Docker.

```bash
cd api
cp .env.example .env                 # then fill in JWT_SECRET (e.g. `openssl rand -hex 48`)
docker compose up -d                 # Postgres 16 on host port 5433
swift run App serve --hostname 127.0.0.1 --port 8080
```

Migrations run automatically on boot. The Vapor server listens on `:8080`; Postgres listens on `:5433` to avoid clashing with the legacy backend on `:5432`.

### Auth surface (Day 1)

| Method | Path | Auth | Notes |
|---|---|---|---|
| `GET`  | `/health`         | — | sanity check |
| `POST` | `/auth/register`  | — | `{email, password, name}` → `{token, user}` |
| `POST` | `/auth/login`     | — | `{email, password}` → `{token, user}` |
| `POST` | `/auth/logout`    | — | `204` (JWT is stateless; client drops the token) |
| `GET`  | `/auth/me`        | Bearer JWT | current user |

JWT is HS256, 30-day expiry, claims `sub` / `email` / `role` / `exp`. Roles: `free`, `premium`, `admin`.

Quick smoke:

```bash
curl -X POST http://127.0.0.1:8080/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"you@example.com","password":"correct horse battery","name":"You"}'
```

## Backend — running tests

Postgres must be running (`docker compose up -d`). Each integration test class migrates and reverts its own schema, so the test DB is always clean.

```bash
cd api

# All tests
swift test

# Unit tests only (no DB required — pure streak/stats logic)
swift test --filter AppTests/HabitStatsServiceTests

# Integration tests only (requires Postgres)
swift test --filter AppTests/HabitControllerTests

# Single test method
swift test --filter AppTests/HabitControllerTests/testCreateHabit
```

## Roadmap

Seven-day plan in [PRP-001 §5](docs/prp/PRP-001-phase1-mobile-foundation.md). Day 1 (Vapor skeleton + Auth) is complete; Day 2 adds Habits + Dashboard.
