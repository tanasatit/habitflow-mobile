# HabitFlow API Reference

**Base URL:** `http://localhost:8080`  
**Auth:** Bearer JWT in `Authorization` header. Token expires 30 days after issue.  
**Dates:** All timestamps are ISO 8601 UTC, e.g. `2026-05-09T07:00:00Z`.  
**Errors:** `{"error": true, "reason": "..."}` with appropriate HTTP status.

---

## Auth

### `POST /auth/register`
Create a new account.

**Body**
```json
{ "email": "user@example.com", "password": "min8chars", "name": "Taro" }
```
**Response 200**
```json
{ "token": "<jwt>", "user": { "id": "<uuid>", "email": "...", "name": "...", "role": "free" } }
```
**Errors:** 400 invalid email/password/name · 409 email already registered

---

### `POST /auth/login`
**Body**
```json
{ "email": "user@example.com", "password": "..." }
```
**Response 200** — same shape as register  
**Errors:** 401 invalid credentials

---

### `POST /auth/logout`
Stateless — JWT is dropped client-side. Returns 204. No body required.

---

### `GET /auth/me` 🔒
Returns the current user.
```json
{ "id": "<uuid>", "email": "...", "name": "...", "role": "free" }
```

---

## Habits 🔒

### `GET /habits`
List all habits for the current user, sorted by creation date.

**Response 200** — array of habit objects:
```json
[{
  "id": "<uuid>", "userID": "<uuid>", "name": "Morning Run",
  "category": "fitness", "frequency": "daily", "targetTime": "07:00",
  "description": null, "isActive": true,
  "createdAt": "...", "updatedAt": "..."
}]
```

---

### `POST /habits`
**Body**
```json
{ "name": "Morning Run", "category": "fitness", "frequency": "daily", "targetTime": "07:00", "description": null }
```
`frequency` defaults to `"daily"` if omitted. All fields except `name` are optional.  
**Response 201** — habit object

---

### `GET /habits/:id`
Returns a single habit. **404** if not found or not owned by caller.

---

### `PUT /habits/:id`
Full or partial update. All fields optional.
```json
{ "name": "Evening Run", "category": null, "targetTime": "18:00", "description": null, "isActive": true }
```
**Response 200** — updated habit object  
**Errors:** 403 not your habit · 404 not found

---

### `DELETE /habits/:id`
Soft-deletes the habit. **Response 204**  
**Errors:** 403 · 404

---

### `POST /habits/:id/log`
Mark a habit as completed for today (UTC). Duplicate logs on the same UTC day are rejected.
```json
{ "completedAt": "2026-05-09T08:00:00Z", "notes": "felt great" }
```
`completedAt` and `notes` are optional — omitting `completedAt` uses `now()`.  
**Response 201** — log object:
```json
{ "id": "<uuid>", "habitID": "<uuid>", "userID": "<uuid>", "completedAt": "...", "notes": null, "createdAt": "..." }
```
**Errors:** 409 already logged today · 403 not your habit

---

### `DELETE /habits/:id/log`
Remove today's log entry (unlog). **Response 204**  
**Errors:** 404 no log for today · 403 not your habit

---

### `GET /habits/:id/stats`
**Response 200**
```json
{
  "habitID": "<uuid>",
  "currentStreak": 8,
  "longestStreak": 14,
  "completionRate": 0.857,
  "weekGrid": [true, true, false, true, true, true, false]
}
```
`weekGrid` is Mon–Sun for the current UTC week. `completionRate` is over the last 30 days.

---

## Dashboard 🔒

### `GET /dashboard`
Single-call overview for the home screen.

**Response 200**
```json
{
  "user": { "id": "<uuid>", "name": "Taro", "role": "free" },
  "overallStreak": 5,
  "habitsSummary": { "total": 4, "active": 4, "completedToday": 2 },
  "todayHabits": [
    { "habit": { ...habit object... }, "completedToday": true, "currentStreak": 8 }
  ]
}
```

---

## Calendar 🔒

### `GET /calendar?start=<iso>&end=<iso>`
Returns events where `startAt` falls within `[start, end)`. Both params required.

**Response 200** — array of event objects:
```json
[{
  "id": "<uuid>", "userID": "<uuid>", "title": "Morning Run",
  "notes": "Easy pace", "startAt": "...", "endAt": "...",
  "allDay": false, "createdAt": "...", "updatedAt": "..."
}]
```
**Errors:** 400 missing/invalid params or end < start

---

### `POST /calendar`
```json
{ "title": "Morning Run", "notes": "Easy pace", "startAt": "...", "endAt": "...", "allDay": false }
```
`notes` and `allDay` optional. `allDay` defaults to `false`.  
**Response 201** — event object  
**Errors:** 400 endAt ≤ startAt

---

### `PATCH /calendar/:id`
Partial update — any subset of fields.
```json
{ "title": "Evening Run", "startAt": "...", "endAt": "...", "notes": null, "allDay": null }
```
**Response 200** — updated event object  
**Errors:** 400 endAt ≤ startAt · 403 not your event · 404 not found

---

### `DELETE /calendar/:id`
Soft-deletes the event. **Response 204**  
**Errors:** 403 · 404

---

## AI Coach 🔒

### `POST /ai/chat`
Send a message to the AI coach. The AI can read your habits and create calendar events on your behalf.

**Body**
```json
{ "message": "Schedule morning runs Mon/Wed/Fri next week at 7am" }
```
**Response 200**
```json
{ "reply": "Done! I've scheduled 3 morning runs for you.", "calendarUpdated": true }
```
`calendarUpdated: true` means the AI called `write_calendar` and new events are now in your calendar.

**Errors:** 400 empty message · 503 GEMINI_API_KEY not configured · 502 Gemini unreachable

**AI tools available to the model:**
| Tool | What it does |
|---|---|
| `get_user_habits` | Reads the caller's active habits (name, category, frequency) |
| `write_calendar` | Creates one or more calendar events for the caller |

---

## Admin 🔒🛡️

> All `/admin/*` routes require `role: admin`. Non-admin token → 403.

### `GET /admin/users`
List all users sorted by creation date.

**Response 200**
```json
[{ "id": "<uuid>", "email": "...", "name": "...", "role": "free", "createdAt": "..." }]
```

---

### `PATCH /admin/users/:id/role`
**Body**
```json
{ "role": "premium" }
```
Valid roles: `free` · `premium` · `admin`  
**Response 200** — updated `AdminUserResponse`  
**Errors:** 400 invalid role · 404 user not found

---

### `POST /admin/seed`
Idempotent demo seed. Safe to call multiple times — skips if demo user already has habits.

**Response 200**
```json
{ "message": "Seed complete", "userEmail": "demo@habitflow.app", "password": "Demo1234!" }
```
Creates: demo user + 4 habits (Morning Run, Read 10 Pages, Meditate, Drink Water) + 8 days of logs each + 3 upcoming Mon/Wed/Fri calendar events at 07:00–07:30 UTC.

---

## Utility

### `GET /health`
```json
{ "status": "ok" }
```
No auth required.

---

## Known Limitations

| Area | Limitation |
|---|---|
| **Auth** | JWTs are stateless — logout does not invalidate the token. A revoked token remains valid until expiry (30 days). |
| **AI Coach** | No conversation history. Each `/ai/chat` request is a fresh context — the AI has no memory of previous messages. |
| **AI Coach** | One function-call round-trip max. If the AI needs two tool calls in one response (e.g. fetch habits *and* write calendar), only the first is executed. |
| **AI Coach** | Gemini's date/day-of-week interpretation can be slightly off (e.g. schedules Tuesday instead of Monday). Dates and times are correct; weekday names are approximate. |
| **Habits** | `frequency` is a free-text string (`"daily"`, `"weekly"`, etc.) — no enforcement or parsing on the backend. |
| **Habits** | Logs can only be un-logged for *today* (UTC). Past log entries cannot be removed via the API. |
| **Calendar** | Deleted events (soft-delete) are permanently hidden — no restore endpoint. |
| **Roles** | `premium` role exists in the schema but no paywall or feature gating is implemented. |
| **Admin** | No user delete endpoint. |
| **Pagination** | No pagination on any list endpoint (`GET /habits`, `GET /calendar`, `GET /admin/users`). |
