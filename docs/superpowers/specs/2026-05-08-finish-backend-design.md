# HabitFlow Backend — Finish Sprint Design
**Date:** 2026-05-08  
**Scope:** Days 3–6 backend (CalendarEvent, AI Coach, Admin minimal, Demo Seed)  
**Approach:** Critical path — every demo checklist step covered; admin counters and premium paywall backend skipped per cut list.

---

## 1. CalendarEvent CRUD (Day 3)

### Model — `CalendarEvent`
| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users, cascade delete |
| `title` | String | required |
| `notes` | String? | optional |
| `start_at` | Date | UTC timestamp |
| `end_at` | Date | UTC timestamp |
| `all_day` | Bool | default false |
| `created_at` | Date? | auto |
| `updated_at` | Date? | auto |
| `deleted_at` | Date? | soft delete |

### Migration — `CreateCalendarEvent`
Standard Fluent `SchemaBuilder`. Registers after `CreateHabitLog` in `configure.swift`.

### Endpoints
```
GET  /calendar?start=&end=   owner-filtered; both params required (ISO8601 full datetime, e.g. 2026-05-08T00:00:00Z); 400 if missing or end < start
POST /calendar               create; 400 if endAt < startAt
PATCH /calendar/:id          partial update (any subset of title/notes/startAt/endAt/allDay); 403 if not owner
DELETE /calendar/:id         soft delete; 403 if not owner
```

### DTOs
- `CreateCalendarEventRequest` — `title`, `notes?`, `startAt`, `endAt`, `allDay?`
- `UpdateCalendarEventRequest` — all fields optional
- `CalendarEventResponse` — `id`, `userID`, `title`, `notes`, `startAt`, `endAt`, `allDay`, `createdAt`, `updatedAt`

### Error handling
- Missing/invalid `start` or `end` query params → 400
- `endAt` < `startAt` → 400 `"endAt must be after startAt"`
- Non-owner access → 403

---

## 2. AI Coach (Day 4)

### Components

**`GeminiClient`** (`Services/GeminiClient.swift`)  
- Thin async HTTP wrapper around `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent`
- Auth: `?key=GEMINI_API_KEY` query param (loaded from env; abort 500 if missing)
- Sends and receives raw `GenerateContentRequest` / `GenerateContentResponse` Codable structs
- No retry logic, no state

**`AICoachService`** (`Services/AICoachService.swift`)  
- Owns the function-calling loop (max 1 tool round-trip — sufficient for demo)
- Takes `userID`, `message`, Vapor `Application` (for DB access)
- Returns `(reply: String, calendarUpdated: Bool)`

**Function-calling loop:**
1. Build `GenerateContentRequest` with user message + two function declarations
2. POST to Gemini
3. If response part is `functionCall`:
   - `get_user_habits` → query `Habit` table for caller's active habits → send `functionResponse`
   - `write_calendar` → create `CalendarEvent` rows → send `functionResponse`; set `calendarUpdated = true`
   - POST again with full conversation history
4. Extract text from final response → return

**Two Gemini tool declarations:**
```
get_user_habits()
  description: "Returns the user's active habits (name, category, frequency)."
  parameters: none

write_calendar(events: array)
  description: "Creates calendar events for the user."
  parameters:
    events: array of { title: string, startAt: string (ISO8601), endAt: string (ISO8601), notes?: string }
```

**`AICoachController`** (`Controllers/AICoachController.swift`)
```
POST /ai/chat   Bearer JWT
Body:   { "message": String }
Reply:  { "reply": String, "calendarUpdated": Bool }
```

### Env var
`GEMINI_API_KEY` — added to `.env.example`

### Error handling
- Missing `GEMINI_API_KEY` → abort 500 on boot
- Gemini HTTP error → 502 `"AI service unavailable"`
- Empty reply from Gemini → 502 `"AI returned no response"`

---

## 3. Admin — Minimal (Day 5)

### Middleware — `AdminMiddleware`
`AsyncMiddleware` that reads `UserPayload` from request auth context; throws 403 if `role != .admin`. Chained after `JWTAuthenticator` + `guardMiddleware`.

### Endpoints
```
GET   /admin/users            list all users; response: [AdminUserResponse]
PATCH /admin/users/:id/role   body: { "role": "free" | "premium" | "admin" }; 400 on invalid role
```

### DTOs
- `AdminUserResponse` — `id`, `email`, `name`, `role`, `createdAt`
- `UpdateRoleRequest` — `role: String`

### What's explicitly excluded
- Admin stats counters (cut list)
- User delete (not in demo flow)
- Premium paywall backend logic (cut list)

---

## 4. Demo Seed — `POST /admin/seed` (Day 6)

Admin-only endpoint. Idempotent — safe to call multiple times (checks for existing demo user by email before inserting).

**Creates:**
1. User `demo@habitflow.app` / `Demo1234!` (role: `free`)
2. Four habits: Morning Run, Read 10 Pages, Meditate, Drink Water
3. `HabitLog` entries backdated 8 days on all 4 habits (streak ring shows 8)
4. Three `CalendarEvent` rows — Mon/Wed/Fri runs at 07:00–07:30 UTC in the upcoming week

**Response:** `{ "message": "Seed complete", "userEmail": "demo@habitflow.app", "password": "Demo1234!" }`

---

## Build order

| Order | Piece | Estimated time |
|---|---|---|
| 1 | CalendarEvent (model + migration + controller + DTOs) | ~30 min |
| 2 | AI Coach (GeminiClient + AICoachService + controller) | ~75 min |
| 3 | Admin middleware + 2 endpoints | ~25 min |
| 4 | Demo seed endpoint | ~20 min |

Total: ~2.5 hours

---

## Files to create

```
api/Sources/App/Models/CalendarEvent.swift
api/Sources/App/Migrations/CreateCalendarEvent.swift
api/Sources/App/DTOs/CalendarEventDTOs.swift
api/Sources/App/Controllers/CalendarEventController.swift
api/Sources/App/Services/GeminiClient.swift
api/Sources/App/Services/AICoachService.swift
api/Sources/App/DTOs/AICoachDTOs.swift
api/Sources/App/Controllers/AICoachController.swift
api/Sources/App/Middleware/AdminMiddleware.swift
api/Sources/App/DTOs/AdminDTOs.swift
api/Sources/App/Controllers/AdminController.swift
```

## Files to edit

```
api/Sources/App/configure.swift   — register CalendarEvent migration
api/Sources/App/routes.swift      — register 4 new controllers
api/.env.example                  — add GEMINI_API_KEY
```
