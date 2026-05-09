# HabitFlow Mobile — Progress Journal

Day-by-day record of what got built, what was decided, and what's next.
Most recent day on top.

**Team:** Tai (macOS · iOS) · Taro (Windows · Vapor backend).
**Delivery target:** clean run on the iOS Simulator. No deployment, no TestFlight.
**Graded on:** functionality, completeness, work quality, usefulness, creativity, level of difficulty, UX/UI.

Plan reference: [`prp/PRP-001-phase1-mobile-foundation.md`](prp/PRP-001-phase1-mobile-foundation.md). Duo split: [`collaboration.md`](collaboration.md).

---

## Day 2 — Habits + Dashboard API · 2026-04-26 · DONE

**Owner:** Taro (`api/`)
**Goal (PRP §5 Day 2):** Full habit + dashboard surface works via `curl`.

### Built
- `Habit` model + `CreateHabit` migration (user_id FK cascade, soft-delete, frequency/category/target_time/description)
- `HabitLog` model + `CreateHabitLog` migration (habit_id + user_id FKs cascade, hard-delete)
- `HabitStatsService` — pure Swift, injectable `today:` for testability; UTC date math throughout
  - `currentStreak` — counts from today or yesterday (preserves streak before user logs at 9am)
  - `longestStreak` — full all-time run via sorted DateComponents → noon-UTC anchor
  - `completionRate` — sliding 30-day window
  - `weekGrid` — 7-element Bool array, index 0 = 6 days ago, index 6 = today
- `HabitController` — 8 endpoints:
  - `GET /habits` — list user's habits (sorted by created_at)
  - `POST /habits` — create; 400 on empty name
  - `GET /habits/:id` — show; 403 if not owner
  - `PUT /habits/:id` — partial update (any subset of name/category/targetTime/description/isActive)
  - `DELETE /habits/:id` — soft delete; 403 if not owner
  - `POST /habits/:id/log` — log completion; optional body `{completedAt, notes}`
  - `DELETE /habits/:id/log` — unlog most-recent today log; 404 if none
  - `GET /habits/:id/stats` — full stats response
- `DashboardController` — `GET /dashboard`: single bulk log fetch (90-day window, no N+1), stats computed in Swift
- Admin seed: on startup, if `ADMIN_EMAIL`/`ADMIN_PASSWORD`/`ADMIN_NAME` env vars set, creates admin user idempotently

### Verified
| Check | Result |
|---|---|
| `swift build` | clean, 0 warnings |
| `swift test` | 1 / 1 passing |
| `POST /habits` | 201, HabitResponse |
| `GET /habits` | array, sorted by created_at |
| `PUT /habits/:id` | partial update applied |
| `DELETE /habits/:id` | 204, gone from list |
| `POST /habits/:id/log` | 201, HabitLogResponse, completedAt ≈ now |
| `GET /habits/:id/stats` | currentStreak=1, weekGrid[6]=true after log |
| `DELETE /habits/:id/log` | 204, streak drops to 0, weekGrid[6]=false |
| `GET /dashboard` | overallStreak=1, completedToday=1 for logged habit |
| Ownership 403 | `{"error":true,"reason":"Not your habit"}` from other user's token |
| Admin seed | `role: admin` on `/auth/me` with seeded credentials |

### Decisions
- **`completedAt` is `Date` not `date`-only:** avoids Fluent casting complexity; stats service normalises to calendar day in UTC.
- **`DELETE /habits/:id/log` deletes most-recent today log:** matches iOS toggle semantics — no log ID needed from client.
- **Dashboard: single bulk log query (90-day):** avoids N+1; 90 days covers any displayable streak.
- **`HabitStatsService` has no Vapor imports:** pure Foundation struct, trivially unit-testable.

### Contract frozen
`/habits/*` and `/dashboard` shapes are stable for Tai to wire iOS.

---

## Day 1 — Vapor skeleton + Auth · 2026-04-25 · DONE

**Owner:** Tai bootstrapped; Taro inherits ownership of `api/` from Day 2.
**Goal (PRP §5 Day 1):** Register / login / get-me from terminal.

### Built
- `api/` — Vapor 4 server, SwiftPM, Swift 6 strict concurrency
- Dependencies: `vapor`, `fluent`, `fluent-postgres-driver`, `jwt`
- `docker-compose.yml` — Postgres 16 on host port **5433**
- `.env` (gitignored) + `.env.example`; root `.gitignore`
- `User` model + `user_role` enum migration (`free` / `premium` / `admin`), email unique, soft delete
- Endpoints:
  - `GET /health`
  - `POST /auth/register` → `{token, user}`
  - `POST /auth/login` → `{token, user}`
  - `POST /auth/logout` → 204 (stateless JWT, client drops token)
  - `GET /auth/me` (bearer) → user
- `UserPayload` JWT (HS256, 30-day exp, claims `sub` / `email` / `role` / `exp`)
- `JWTAuthenticator` async bearer middleware
- Bcrypt password hashing via `req.password.async`
- 1 XCTVapor smoke test on `/health`

### Verified
| Check | Result |
|---|---|
| `swift build` | clean |
| `swift test` | 1 / 1 passing, no warnings |
| `/health` | 200 |
| Register valid user | 200, JWT issued |
| Register short password | 400 |
| Register duplicate email | 409 |
| Login correct creds | 200 |
| Login wrong password | 401 |
| `/auth/me` with bearer | 200 |
| `/auth/me` without bearer | 401 |
| Postgres `users` row | bcrypt hash (`$2b$12$…`), role `free`, timestamps UTC |

### Decisions
- **Repo layout:** monorepo (`api/` and future `ios/` siblings under `habitflow-mobile/`).
- **JWT:** HS256, 30-day expiry. No refresh tokens for Phase 1.
- **Logout endpoint:** kept for symmetry; stateless, client-side discard.
- **Migration:** auto-run on boot in non-test environments (skipped under `.testing`).

### Carry-overs / nice-to-haves
- More auth tests (register / login / me happy-paths via XCTVapor) — scheduled for Day 7.
- Hand-off note for Taro: `api/` runs cleanly via `docker compose up -d` + `swift run App serve`. See [`collaboration.md`](collaboration.md) §5 for Windows setup.

---

## Day 2 — Habits + Dashboard API · iOS scaffold · planned

**Taro (`api/`)**
- `Habit` + `HabitLog` models + migrations
- `Habit` CRUD, log/unlog, `/habits/:id/stats`
- `HabitStatsService` — current streak, longest streak, completion rate, 7-day grid (pure, unit-testable)
- `GET /dashboard` aggregate
- Admin seed user from env vars
- Smoke-test with curl

**Tai (`ios/`)**
- Xcode project (iOS 17+), Swift 6 strict concurrency, Tropical Punch theme
- `APIClient`, `Endpoint`, `APIError`, `KeychainStore`, `AuthStore` (`@Observable`)
- `LoginView` + `RegisterView`, auto-login on launch
- 5-tab `TabView` shell with placeholder views
- Wires to existing `/auth/*` endpoints (already shipped Day 1)

---

## Day 3 — Calendar API · Today screen · planned

**Taro**
- `CalendarEvent` model + migration
- `GET /calendar?start=&end=`, `POST /calendar`, `PATCH /calendar/:id`, `DELETE /calendar/:id`

**Tai**
- `TodayView` pulling `/dashboard` + today's habits
- Check-off → `POST /habits/:id/log` with optimistic UI + haptic feedback
- Streak ring with pulsing flame animation
- 7-day completion chart

End-of-day target: log in → see today's habits → tick one off → streak updates.

---

## Day 4 — AI Coach backend · Habits + Calendar UI · planned

**Taro**
- `GeminiClient` — REST `generateContent` + function-calling
- Tool surface: `get_user_habits()`, `write_calendar(events: [...])`
- `AICoachService`
- `POST /ai/chat` → `{reply, calendar_updated}`

**Tai**
- `HabitsListView`, `HabitDetailView` (stats + 7-day grid), `HabitEditView`
- `MonthView`, `DayDetailView`, `EventEditSheet`
- SwiftData mirrors for `Habit` + `CalendarEvent`

---

## Day 5 — Admin endpoints · AI Coach UI · planned

**Taro**
- `/admin/users` (list / get / update-role / delete)
- `/admin/stats` (counts only)
- Refine AI Coach: better prompts, tool error handling

**Tai**
- `ChatView` — bubble list + input bar
- On `calendar_updated`, invalidate calendar query
- Premium gating — paywall card if `role == "free"`

---

## Day 6 — Backend hardening · Admin UI + polish · planned

**Taro**
- Backend tests for habits + calendar happy paths
- Bug fixes from joint QA
- Demo seed script — a few habits with backdated logs so the streak ring shows real numbers

**Tai**
- `AdminUsersView` (gated by `role == admin`)
- `ProfileView` + logout
- Polish pass: haptics on every actionable surface, spring transitions, empty states, error banners, app icon, launch screen, dark mode review

---

## Day 7 — Tests, demo prep · planned

- Taro: ~6 XCTVapor happy-path tests (auth, habits, dashboard, calendar)
- Tai: 2–3 iOS view-model tests
- Joint QA on Simulator across all 5 tabs + Admin
- Bug bash; cut from drop-list if needed
- README with run instructions for both `api/` and `ios/`
- Demo script + screen recording of the golden path on iOS Simulator
