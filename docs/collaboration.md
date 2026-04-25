# HabitFlow Mobile — Duo Collaboration Plan

Two people, seven days, one Simulator demo.

| Person | Machine | Owns |
|---|---|---|
| **Tai** | macOS | `ios/` (SwiftUI app), demo recording on Simulator |
| **Taro** | Windows | `api/` (Vapor server), backend tests, demo seed data |
| **Both** | — | `docs/`, API contract, code review, joint QA |

**Delivery:** the entire app runs on Tai's Mac at demo time — Postgres in Docker, Vapor on `:8080`, iOS Simulator on `:8080`. **No deployment, no TestFlight.**

Plan reference: [`prp/PRP-001-phase1-mobile-foundation.md`](prp/PRP-001-phase1-mobile-foundation.md). Day-by-day journal: [`progress.md`](progress.md).

---

## 1. Grading rubric — and how each axis gets won

The project is graded on **functionality, completeness, work quality, usefulness, creativity, level of difficulty, UX/UI**. Every decision below is a vote on one of these.

| Axis | Owner | How we score points |
|---|---|---|
| **Functionality** | Both | Every endpoint and every screen does what it claims. Smoke-tested daily. Joint QA Day 6–7. |
| **Completeness** | Both | All 5 tabs + Admin functional. Empty / loading / error states on every list & detail. Logout fully resets state. No half-built screens. |
| **Work quality** | Both | `swift build` & `swift test` clean under Swift 6 strict. Backend ≥6 happy-path tests. iOS ≥2–3 VM tests. PR review on every change. No `.env` in git. README that actually runs. |
| **Usefulness** | Tai | Realistic flows: morning open → today's habits → quick check-off → streak feedback. Don't ask the user to fill out 5 fields to create a habit. |
| **Creativity** | Tai (Taro on AI side) | Pulsing flame on streak counter. AI Coach with Gemini function-calling that *writes* calendar events from a sentence. Tropical Punch theme. Custom transitions. |
| **Level of difficulty** | Both | Swift 6 strict concurrency. Custom Vapor backend (not Firebase). JWT auth + role-based middleware. Gemini function-calling (multi-tool). SwiftData mirrors of server state. |
| **UX/UI** | Tai | Tropical Punch palette + typography consistent. Dark Mode intentional. Haptics on every actionable touch. Spring animations, not linear. Dynamic Type respected. App icon + launch screen. |

If something doesn't move at least one of these axes, drop it.

---

## 2. Day-by-day split

Backend stays one step ahead of the iOS work that depends on it. Anything not blocked runs in parallel.

| Day | Taro — backend (`api/`) | Tai — iOS (`ios/`) |
|---|---|---|
| 1 | (Tai bootstrapped: auth scaffold ✓) | — |
| 2 | Habits CRUD + HabitLog + `HabitStatsService` + `GET /dashboard` + admin seed | Xcode project, Swift 6 strict, Tropical Punch theme, `APIClient`, `KeychainStore`, `AuthStore`, Login/Register, TabView shell. Wires to existing `/auth/*`. |
| 3 | Calendar API (CRUD + date-range filter) | TodayView pulling `/dashboard`, check-off → `POST /habits/:id/log`, streak ring with pulsing flame. End-of-day: log in → tick a habit → streak updates. |
| 4 | AI Coach backend (`GeminiClient` + tool surface + `POST /ai/chat`) | Habits list / detail / edit, MonthView / DayDetail / EventEditSheet, SwiftData mirrors |
| 5 | `/admin/users`, `/admin/stats`, AI prompt refinement | ChatView (bubbles + input), premium paywall card |
| 6 | Backend tests, bug fixes, **demo seed script** with backdated logs so streaks look real | AdminUsersView, ProfileView + logout, polish (haptics, transitions, empty states, app icon, launch screen, dark mode) |
| 7 | Final backend tests + bug bash, backend README | iOS view-model tests, joint QA on Simulator, README, **screen recording of the golden path** |

**Drop-list (cut first if behind, in order):** SwiftData caching → admin counters → tests beyond happy paths → premium paywall card.

---

## 3. API contract — single source of truth

The contract is **PRP-001 §4** (endpoint list) + the Codable types in `api/Sources/App/DTOs/`. Rules:

- Any change to a request or response shape requires a PR with both names on it.
- DTO field names are camelCase in JSON. Use `@JSONField` / explicit `CodingKeys` if internal model fields differ.
- iOS `Codable` types in `ios/Core/Networking/` mirror backend DTOs **exactly**. If they drift, the iOS side is the bug.
- Errors follow Vapor's default: `{"error": true, "reason": "..."}`. iOS surfaces `reason` in error banners.
- Auth: `Authorization: Bearer <jwt>` on every protected route. Store JWT in Keychain.

**Contract checkpoints** — Taro posts a short message in chat when each surface stabilises. After "frozen," changes are still possible but require an explicit heads-up.

| EOD | Frozen surface |
|---|---|
| Day 1 | `/auth/*` (DONE) |
| Day 2 | `/habits/*`, `/dashboard` |
| Day 3 | `/calendar` |
| Day 4 | `/ai/chat` |
| Day 5 | `/admin/*` |

---

## 4. Git workflow

- `main` is the trunk. **No force-push.**
- Branches: `feat/api/<slug>`, `feat/ios/<slug>`, `fix/<area>/<slug>`, `docs/<slug>`.
- PRs require the other person's LGTM (or an emoji ack) before merge. Solo-merge only when the other is offline and the change is obviously safe (typos, comments).
- Each day's last commit on `main` should leave the project in a runnable state — the PRP demands a working build per day.
- High-conflict files — touch in small PRs: `Package.swift`, `configure.swift`, `routes.swift`, `Migrations/` registration list, `docker-compose.yml`.
- `.env` is gitignored and **never** committed. `.env.example` documents the keys.

---

## 5. Shared environments

Each person runs their **own** Postgres locally. There is no shared dev DB and no deployed backend.

- **During the week (Days 2–6):** Taro runs `api/` on Windows; Tai runs `api/` on the Mac. They develop against their own local stack. They sync the contract via merged PRs, not via a shared running service.
- **For Tai's iOS development:** Tai pulls the latest `main` (or Taro's feature branch), runs `swift run App serve` locally, and points the Simulator at `http://localhost:8080`.
- **For the demo (Day 7):** Tai runs the latest `main` of `api/` on the Mac. Demo seed script populates the DB before recording. The Simulator hits `http://localhost:8080`. That's it — no cloud, no flaky network.

Postgres on host port **5433** (so it doesn't clash with anything else); Vapor on **8080**.

---

## 6. Taro's Windows setup (first-time, ~30 min)

Recommended path: **WSL2 + Ubuntu + Swift Linux toolchain + Docker Desktop**. Vapor's first-class platform after macOS is Linux, and WSL2 is effectively a Linux dev box.

```powershell
# In PowerShell (admin)
wsl --install -d Ubuntu-22.04
# Reboot, finish Ubuntu setup (username/password)
```

Inside Ubuntu (WSL):

```bash
# 1. Build deps
sudo apt update && sudo apt install -y \
  binutils git gnupg2 libc6-dev libcurl4-openssl-dev libedit2 libgcc-11-dev \
  libpython3-dev libsqlite3-0 libstdc++-11-dev libxml2-dev libz3-dev pkg-config \
  tzdata unzip zlib1g-dev curl

# 2. Swift 6.x — follow the official Ubuntu 22.04 install steps from swift.org
swift --version

# 3. Docker Desktop on Windows — turn on "Use the WSL 2 based engine" + enable
#    Ubuntu integration in Settings → Resources → WSL integration

# 4. Clone INSIDE the WSL filesystem (NOT /mnt/c — that's slow)
cd ~ && git clone <repo-url> habitflow-mobile && cd habitflow-mobile/api

# 5. Bring up Postgres + run the server
cp .env.example .env   # then set JWT_SECRET (run: openssl rand -hex 48)
docker compose up -d
swift run App serve --hostname 127.0.0.1 --port 8080
```

VS Code: install the **WSL** extension (`WSL: Open Folder in WSL…`) and the **Swift** extension. Code lives in the Linux filesystem, edited from Windows.

**Smoke test (Taro should land on the same results as Tai's Day 1 run):**

```bash
curl http://127.0.0.1:8080/health
curl -X POST http://127.0.0.1:8080/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"taro@local.test","password":"12345678","name":"Taro"}'
```

If swift-on-WSL is painful, fallback is a Swift dev container — we'd add a `Dockerfile.dev` and Taro just runs `docker compose up`. Only do this if WSL2 hits a wall.

---

## 7. Daily sync ritual

Async, short. End of each working session, post in your shared chat:

```
Yesterday: <one line>
Today:     <one line>
Blockers:  <or "none">
Contract:  <change to API shape, or "none">
```

If a blocker is on the other person's plate, `@mention` them. No standup call needed unless something's stuck for >2 hours.

---

## 8. Demo day checklist (Day 7, on Tai's Mac)

A clean run from cold:

1. `cd api && docker compose up -d && swift run App serve --hostname 127.0.0.1 --port 8080`
2. Run the demo seed script (creates demo user, a few habits, backdated logs so streak ≥ 5).
3. Open the iOS Simulator, launch HabitFlow.
4. Log in as the demo user → Today screen with **pulsing flame** and real streak.
5. Tick a habit → haptic + ring updates.
6. Habits tab: open detail → 7-day grid + longest streak.
7. Calendar tab: month grid → tap a day → events.
8. Coach tab: "schedule a 30-minute run Mon/Wed/Fri at 7am" → bot confirms → switch to Calendar → events appear on those days.
9. Profile tab: role badge, logout → back to login.
10. Log in as admin → Admin tab → promote a free user to premium → log out, log in as that user → Coach tab now unlocked.
11. Recording captured.

If any step in this list isn't 100% by end of Day 6, that's the Day 7 priority — ahead of new features.

---

## 9. Phase 1 Definition of Done

See [`prp/PRP-001-phase1-mobile-foundation.md`](prp/PRP-001-phase1-mobile-foundation.md) §8. Mirrors the rubric: functionality, completeness, work quality, UX/UI/creativity, demo.
