# PRP-001 · Phase 1 · HabitFlow Mobile Foundation

**Stack:** Swift 6 + SwiftUI (iOS 17+) · Vapor (Server-Side Swift) · PostgreSQL + SwiftData · Gemini API
**Project type:** standalone greenfield — own repo, own DB, own `.env`, own JWT secret, own Gemini key. Zero shared infra with the legacy Go/Next.js HabitFlow app.
**Team:** duo. **Tai** (macOS) — iOS app. **Taro** (Windows) — Vapor backend.
**Window:** ~7 days.
**Delivery target:** runs end-to-end on the iOS Simulator. No deployment, no TestFlight — graded on the Simulator demo.

**Grading rubric (drives all priorities):**
- Functionality of application
- Completeness
- Work quality
- Usefulness
- Creativity
- Level of difficulty
- UX/UI

---

## 1. Scope

### IN SCOPE
1. **Auth** — register, login, logout, JWT in Keychain, auto-login
2. **Tab bar** — Today · Habits · Calendar · Coach · Profile
3. **Today** — greeting, **streak ring with pulsing flame**, today's habits w/ check-off, 7-day completion chart
4. **Habits** — list, create, edit, delete, detail (current streak, longest streak, completion rate, 7-day grid)
5. **Calendar** — month grid, day list, event create/edit/delete, optional habit link
6. **AI Coach (premium)** — Gemini chat; e.g. "schedule my workouts Mon/Wed/Fri 7am" → tool call writes calendar events; sync request/response (no SSE)
7. **Profile** — name, role badge, logout
8. **Admin** (admin role only) — user list, search, change role free/premium/admin, basic counters
9. **Premium gating** — admin manually toggles role; AI Coach is the only premium feature
10. **3-tier RBAC** — free / premium / admin

### OUT OF SCOPE (cut intentionally)
- **Points / leaderboard / any competitive scoring** — personal app, not a competition. Streaks are the only "gamification" surface.
- **Google OAuth login** — multi-day URL-scheme/refresh-token work; brief allows email/password only
- **Google Calendar sync** — out of scope per brief
- **SSE streaming for AI** — synchronous JSON response saves ~1 day
- **Offline write queue** — mutations are online-only
- **Custom habit frequencies beyond `daily`** — keep schema flexible but ship `daily` only

---

## 2. Architecture

### 2.1 Backend — Vapor (greenfield repo)

```
HabitFlowAPI/                        # at habitflow-mobile/api or sibling repo
├── docker-compose.yml               # Postgres only, NEW port (e.g. 5433) to avoid clashes
├── .env                             # DATABASE_URL, JWT_SECRET, GEMINI_API_KEY (all NEW values)
├── Package.swift                    # vapor, fluent, fluent-postgres-driver, jwt
└── Sources/App/
    ├── configure.swift              # routes + middleware + Fluent setup
    ├── Models/                      # User, Habit, HabitLog, CalendarEvent, AIConversation
    ├── Migrations/                  # one per model
    ├── DTOs/                        # Codable Content types
    ├── Controllers/                 # Auth, Habit, Calendar, Dashboard, AICoach, Admin
    ├── Services/
    │   ├── HabitStatsService.swift  # streak math (current + longest)
    │   ├── GeminiClient.swift       # generateContent + function-calling
    │   └── AICoachService.swift
    └── Middleware/                  # JWTAuth, RequireRole, RequirePremium
```

**Decisions**
- Fluent + PostgresKit, async/await throughout
- JWTKit HS256 — claims: `sub`, `email`, `role`, `exp`. Secret is brand new, NOT the Go backend's
- Gemini tool surface (intentionally tiny):
  - `get_user_habits()` — list user's active habits
  - `write_calendar(events: [...])` — bulk insert calendar events
- Chat response shape: `{ "reply": "...", "calendar_updated": true }` — mobile re-fetches calendar when flag set
- No SSE; no Google Calendar tools

### 2.2 Mobile — SwiftUI + Swift 6

```
HabitFlowMobile/                      # at habitflow-mobile/ios or root
├── HabitFlowApp.swift                # @main, root TabView, env injection
├── Core/
│   ├── Networking/                   # APIClient, Endpoint, APIError
│   ├── Auth/                         # AuthStore (@Observable), KeychainStore
│   ├── Persistence/                  # SwiftData mirrors of Habit + CalendarEvent
│   └── DesignSystem/                 # Theme (Tropical Punch), StreakRing, PulsingFlame, PrimaryButton
├── Features/
│   ├── Auth/                         # LoginView, RegisterView, AuthViewModel
│   ├── Today/                        # TodayView w/ streak ring + today's habits
│   ├── Habits/                       # ListView, DetailView, EditView
│   ├── Calendar/                     # MonthView, DayDetailView, EventEditSheet
│   ├── Coach/                        # ChatView, ChatViewModel
│   ├── Profile/                      # ProfileView, SettingsView
│   └── Admin/                        # AdminUsersView (admin-only)
└── Resources/Assets.xcassets
```

**Pattern:** MVVM with `@Observable` view models (Swift 6 Observation). VMs are `@MainActor`; DTOs are `Sendable`.

**Caching strategy:** SwiftData mirrors of `Habit` and `CalendarEvent` for instant render. Auth/dashboard/AI-chat are server-of-truth. Mutations are online-only.

**Pulsing flame** on streak counter:
```swift
Image(systemName: "flame.fill")
    .scaleEffect(pulse ? 1.15 : 1.0)
    .opacity(pulse ? 1.0 : 0.85)
    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
    .onAppear { pulse = true }
```

### 2.3 Repo layout question
Decide before Day 1: do `api/` and `ios/` live as siblings inside `habitflow-mobile/`, or as two separate repos? **Default recommendation:** monorepo with `api/` and `ios/` siblings — easier coordination during the 7-day window.

---

## 3. Data Model (Postgres / Fluent)

```
users          (id uuid pk, email unique, password_hash, name, role, created_at, updated_at, deleted_at)
habits         (id uuid pk, user_id fk, name, category, frequency, target_time, description, is_active, created_at, updated_at, deleted_at)
habit_logs     (id uuid pk, habit_id fk, user_id fk, completed_at, notes, created_at)
calendar_events(id uuid pk, user_id fk, habit_id fk?, title, description, scheduled_date, start_time, duration_minutes, color, is_completed, created_at, updated_at)
ai_conversations(id uuid pk, user_id fk, messages jsonb, created_at, updated_at)
```
*No `points` field. No `subscriptions` table — `users.role` is the source of truth for premium status.*

---

## 4. API Surface

```
POST   /auth/register
POST   /auth/login
POST   /auth/logout
GET    /auth/me                          [auth]

GET    /habits                            [auth]
POST   /habits                            [auth]
GET    /habits/:id                        [auth]
PUT    /habits/:id                        [auth]
DELETE /habits/:id                        [auth]
POST   /habits/:id/log                    [auth]
DELETE /habits/:id/log                    [auth]
GET    /habits/:id/stats                  [auth]

GET    /dashboard                         [auth]

GET    /calendar?start=&end=              [auth]
POST   /calendar                          [auth]
PATCH  /calendar/:id                      [auth]
DELETE /calendar/:id                      [auth]

POST   /ai/chat                           [auth + premium]

GET    /admin/users                       [auth + admin]
GET    /admin/users/:id                   [auth + admin]
PUT    /admin/users/:id                   [auth + admin]
DELETE /admin/users/:id                   [auth + admin]
GET    /admin/stats                       [auth + admin]
```

---

## 5. Seven-Day Plan

Each day ends with a working build.

### Day 1 — Vapor skeleton + Auth
- New repo, `vapor new`, Postgres in Docker (port 5433), `.env`
- User model + migration
- `POST /auth/register`, `/auth/login`, `GET /auth/me`
- JWTKit middleware
- Smoke-test with `curl`
- **Deliverable:** can register/login/get-me from terminal

### Day 2 — Habits + Dashboard API
- Habit + HabitLog models + migrations
- Habit CRUD, log/unlog, stats endpoint
- `HabitStatsService` — current streak, longest streak, completion rate, 7-day grid
- `GET /dashboard` aggregating across habits
- Admin user seed from env
- **Deliverable:** full habit + dashboard surface works via `curl`

### Day 3 — iOS skeleton + Auth + Today
- Xcode project (iOS 17+), Swift 6 strict concurrency, Tropical Punch theme
- `APIClient`, `KeychainStore`, `AuthStore`
- LoginView / RegisterView; auto-login on launch
- TabView shell (5 tabs)
- TodayView pulling `/dashboard` + today's habits, with check-off → `POST /habits/:id/log`
- Streak ring with pulsing flame animation
- **Deliverable:** install on simulator, log in, see today's habits, tick one off

### Day 4 — Habits + Calendar (mobile + Calendar API)
- Backend: CalendarEvent CRUD with date-range filter
- Mobile: HabitsListView, HabitDetailView (stats), HabitEditView
- Mobile: SwiftData mirrors for Habit + CalendarEvent
- Mobile: MonthView (calendar grid), DayDetailView, event create/edit sheet
- **Deliverable:** end-to-end habits + calendar with create/edit/delete

### Day 5 — AI Coach (Gemini)
- Backend: `GeminiClient` (REST `generateContent` + function-calling)
- `AICoachService` with two tools (`get_user_habits`, `write_calendar`)
- `POST /ai/chat` — sync, returns `{reply, calendar_updated}`
- Mobile: ChatView with bubble list + input bar; on `calendar_updated` invalidate calendar query
- Premium gating — paywall card if `role == "free"`
- **Deliverable:** "schedule a 30-min run Mon/Wed/Fri at 7am" → events appear in calendar

### Day 6 — Admin + Polish
- Backend: `/admin/users` (list/get/update-role/delete) + simple `/admin/stats` (counts only)
- Mobile: AdminUsersView (gated by `role == admin`), counters
- ProfileView + logout
- Polish: haptics on check-off (`UIImpactFeedbackGenerator`), spring transitions, empty states, error banners, app icon, launch screen
- **Deliverable:** admin can promote/demote users; UI polished

### Day 7 — Tests, polish, demo prep
- Backend: ~6 XCTVapor happy-path tests (auth, habits, dashboard, calendar)
- iOS: 2–3 view-model tests
- Realistic demo seed data (a few habits with backdated logs to show streaks + flame)
- Joint QA on Simulator across all 5 tabs + Admin
- Bug bash; cut from drop-list if needed
- README with run instructions for both `api/` and `ios/`
- Demo script + screen recording of the golden path
- **Deliverable:** clean run on iOS Simulator from cold start, demo recording in hand

### Drop-list (cut first if behind)
1. SwiftData caching → fetch every time, show spinner
2. Admin counters → leave just the user list
3. Tests beyond auth + habits happy paths
4. Premium paywall card → just disable Coach tab if free

---

## 6. Risks

| Risk | Mitigation |
|---|---|
| Vapor learning curve (Fluent migrations, async middleware) | Day 1 is *just* auth — proves the stack before broadening |
| Gemini function-calling format quirks | Day 5 starts with one hardcoded prompt; fall back to single-tool if multi-tool flaky |
| Swift 6 strict concurrency noise | `@MainActor` VMs, `Sendable` DTOs, `nonisolated(unsafe)` on rare service singletons |
| 7 days is tight | Drop-list above is non-load-bearing |
| Demo backend must run on Tai's Mac | Code is portable Swift; Tai pulls Taro's `api/` branches and runs `swift run App serve` locally for the demo |
| Windows ↔ macOS toolchain drift between Tai and Taro | Pin Swift toolchain version, share `Package.resolved`, CI smoke job optional |

---

## 7. Open Questions

1. **Repo layout** — `habitflow-mobile/{api,ios}` siblings *(decided: siblings, Day 1)*
2. **Gemini API key** — does a fresh key exist, or do we provision one before Day 4?
3. **Demo seed data** — what's the storyline for the recording? (e.g. "morning routine + workout schedule" with a 5-day backdated streak)

---

## 8. Phase 1 Definition of Done

**Functionality**
- [ ] Register / login / logout / `/auth/me` work via curl AND from the iOS app
- [ ] All 5 tabs render real data (Today, Habits, Calendar, Coach, Profile)
- [ ] Habit CRUD + check-off + stats (current/longest streak, completion rate, 7-day grid)
- [ ] Calendar event CRUD (month grid, day list, create/edit/delete, optional habit link)
- [ ] AI Coach chat (premium) — Gemini function-calling writes calendar events
- [ ] Admin view promotes/demotes users (admin role only)

**Completeness**
- [ ] Empty states, loading states, and error banners on every list/detail surface
- [ ] Logout clears Keychain JWT and routes back to Login
- [ ] No dead links, no half-built screens, no unhandled API errors

**Work quality**
- [ ] Vapor on `:8080`, Postgres on `:5433`, both reproducible from `docker compose up` + `swift run`
- [ ] `swift build` and `swift test` clean, no warnings under Swift 6 strict
- [ ] At least 6 backend happy-path tests + 2–3 iOS view-model tests
- [ ] No `.env` / secrets in git

**UX / UI / Creativity**
- [ ] Tropical Punch theme applied consistently (colors, typography, spacing)
- [ ] Streak ring with pulsing flame on Today + habit detail
- [ ] Haptics on check-off, spring transitions, app icon, launch screen
- [ ] Dark Mode looks intentional (not just defaults)
- [ ] Dynamic Type respected on primary screens

**Demo**
- [ ] Cold start on iOS Simulator: launch sim → run backend → launch app → log in → tick a habit → see streak → use AI Coach → see calendar event appear → admin view as admin
- [ ] Demo recording captured
- [ ] `progress.md` reflects the actual current state at end of each day
