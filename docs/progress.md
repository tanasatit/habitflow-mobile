# HabitFlow Mobile — Progress Journal

Day-by-day record of what got built, what was decided, and what's next.
Most recent day on top.

**Team:** Tai (macOS · iOS) · Taro (Windows · Vapor backend).
**Delivery target:** clean run on the iOS Simulator. No deployment, no TestFlight.
**Graded on:** functionality, completeness, work quality, usefulness, creativity, level of difficulty, UX/UI.

Plan reference: [`prp/PRP-001-phase1-mobile-foundation.md`](prp/PRP-001-phase1-mobile-foundation.md). Duo split: [`collaboration.md`](collaboration.md).

---

## Days 3–5 — Full iOS frontend + backend hardening · 2026-04-27 → 2026-05-11 · DONE

**Owner:** Tai (`ios/`) · Taro (`api/` branch `api/calendar-ai-admin`)

### Built — iOS (Tai)

**Foundation**
- `xcodegen` project spec (`project.yml`), iOS 17+, Swift 6 strict concurrency
- "Tropical Punch" design system: `Color+HabitFlow`, `Font+HabitFlow`, `HFComponents` (HFCard, HFPrimaryButton, HFProgressRing, pulsingFlame, HFErrorBanner, HFTextField)
- `APIClient` (generic `send<T>` + `sendVoid`, ISO 8601 encode/decode, typed `APIError` including `.forbidden`)
- `Endpoint` enum covering all surfaces: auth, habits, calendar, dashboard, AI chat
- `KeychainStore` + `AuthStore` (`@Observable`, auto-login on launch)
- `AppNavigator` (`@Observable`) — programmatic tab switching + calendar date targeting

**Auth**
- `LoginView` + `RegisterView` with `HFTextField` eye-toggle for password reveal/hide
- Auto-login from Keychain on relaunch; logout clears token + navigates to login

**Today tab**
- Pulls `GET /dashboard`; shows greeting, overall streak with pulsing flame, `HFProgressRing` for daily completion
- Habit rows with category icon, streak badge, toggle circle (optimistic UI + haptic feedback)
- "View All" navigates to Habits tab via `AppNavigator`
- Pull-to-refresh; empty state

**Habits tab**
- 2-column `LazyVGrid` of `BentoCard`s; each card shows category icon/badge, name, 7-dot Mon–Sun week grid (from `weekGrid`), streak, completion %
- Long-press context menu: **Edit** (pre-filled `EditHabitSheet`, `PATCH /habits/:id`) + **Delete** (swipe-to-delete)
- `CreateHabitSheet`: name, 3-column category chip grid, description
- Free-tier limit: 403 from server opens `HabitLimitPaywallSheet` (lock icon, feature list, upgrade CTA)

**Flow (AI Coach) tab**
- Premium gating: free users see paywall card
- Hamburger sidebar (280 pt slide) with full chat history — persisted to `UserDefaults`, survives app restarts
- Suggestion chips on empty state; `BubbleView` with squared tail corner, `TypingIndicator` (3 animated dots)
- AI-created event chips below reply bubble (teal, tappable) → navigates to Calendar tab on the event's date via `AppNavigator`
- New-conversation button saves session to sidebar

**Calendar tab**
- `weekOffset` state — chevron buttons + swipe gesture to navigate weeks; "Today" button when off current week
- Day chip highlights: orange filled = selected, orange ring = today, red dot = has events
- Tappable "This Week." header → `MonthPickerSheet` (Mon-first grid, event dots, tap to jump)
- `EventRow`: time gutter, duration, left orange accent bar; swipe-to-delete
- `AddEventSheet`: title, all-day toggle, start/end `DatePicker`, notes; labels no longer clipped
- Auto-reloads when AI creates events via `NotificationCenter`
- `AppNavigator.calendarTargetDate` — jumping from event chip scrolls to correct week + selects day

**Profile tab**
- Initials avatar with orange border, role badge (teal=Premium, grey=Free, dark=Admin)
- Live stats from `GET /dashboard`: overall streak, today completion ratio (`done/active`), active habit count
- Settings rows (UI only), logout with confirmation dialog

### Built — Backend (Taro, branch `api/calendar-ai-admin`)

- **JWT logout** now truly invalidates tokens via `revoked_tokens` table + `jti` claim check
- **`POST /ai/chat`** accepts `timezone` field; AI anchors local times correctly; response now includes `events: [ScheduledEvent]?`
- **AI conversation history** — last 20 messages per user persisted in `ai_conversations` table
- **AI multi-tool loops** — up to 5 tool-call rounds per message (fixes stuck multi-step requests)
- **`PATCH /habits/:id`** alias added (previously `PUT` only)
- **Frequency validation** — only `daily/weekly/monthly/custom` accepted
- **Past log deletion** — `DELETE /habits/:id/log?date=yyyy-MM-dd`
- **Free-tier habit cap** — 6th `POST /habits` returns 403 for free users
- **Calendar soft-delete restore** — `POST /calendar/:id/restore`
- **Pagination** — `GET /habits`, `GET /calendar`, `GET /admin/users` return `{ items, metadata }` envelope; iOS updated to unwrap `.items`
- **Admin user delete** — `DELETE /admin/users/:id`
- ISO 8601 date encoding configured globally in `configure.swift`

### Bug fixes
- `APIClient`: shared `JSONEncoder` with `.iso8601` strategy — dates were being sent as Unix timestamps, breaking `POST /calendar`
- `CalendarView`: `onChange(of: weekOffset)` wrapped in `Task {}` (async closure not accepted by modifier)
- `AIResponse`: added `events: [ScheduledEvent]?` to model; `ChatMessage.Role` made `Codable` for persistence
- `APIError.forbidden` added; `APIClient` handles 403 separately from generic server errors

### Decisions
- **`AppNavigator`** as shared `@Observable` (not `NotificationCenter`) for tab switching — type-safe, testable
- **Chat sessions to `UserDefaults`** (not backend) — keeps AI Coach stateless from iOS's perspective; server already stores message history
- **No SSE streaming** — cut from scope per CLAUDE.md; single request/response cycle
- **No Google Calendar sync** — cut from scope

### Pending — waiting on Taro
| # | What | Detail |
|---|---|---|
| 1 | AI tools for user data | Gemini needs `get_user_habits()` and `get_calendar_events(range)` tool functions so AI can answer "did I complete all?" |
| 2 | Buddhist Era year bug | AI outputs year 2569 (BE) in ISO 8601 fields; iOS Thai calendar adds 543 → shows 3112. Gemini system prompt must specify Gregorian/CE years only, e.g. "Current Gregorian year is 2026." |
| 3 | Calendar event category + edit | Add `category: String?` to `CalendarEvent` model + migration; add `PATCH /calendar/:id` |

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
