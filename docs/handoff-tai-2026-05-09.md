# Backend Handoff — 2026-05-09

Hey Tai, this doc covers every backend change made today. Organized by: what was broken, what we did, and what you need to wire up on iOS.

---

## 0. Critical bug fix — `POST /calendar` was rejecting dates from iOS

**Problem.** Vapor's default JSON encoder/decoder treats `Date` as a raw `Double` (seconds since 2001-01-01). The iOS app sends ISO 8601 strings like `"2026-05-10T07:00:00Z"`. Vapor was throwing 400 on every request that included a date field — meaning `POST /calendar`, `POST /habits/:id/log`, and `PATCH /calendar/:id` all failed from your device even though they worked in Postman with numeric timestamps.

**Fix.** Configured ISO 8601 globally in `configure.swift`. Every date field the server sends or receives is now a string in the form `"2026-05-10T07:00:00Z"`. No iOS change needed — just stop sending numeric timestamps if you had any workarounds in place.

---

## 1. Auth — JWT logout now actually invalidates tokens

**Problem.** `POST /auth/logout` returned 204 but the token kept working for 30 days. A user who logged out could still access any protected endpoint with their old token.

**Fix.** Logout now writes the token's ID (a `jti` claim) to a `revoked_tokens` table. Every authenticated request checks that table. A revoked token gets 401 immediately.

**What you need to do on iOS:** Nothing structural changes. Logout still hits `POST /auth/logout` with the Bearer token in the header. After that call succeeds, the token is dead — existing behaviour. One note: any tokens issued before this deploy (before today's backend restart) will fail to authenticate because they're missing the `jti` field. Users will need to log in once.

---

## 2. AI Coach — response now includes created calendar events

**Problem.** When the AI created calendar events, the iOS app had no way to know which events were created or what they were called.

**Fix.** `POST /ai/chat` now returns an `events` field alongside `calendarUpdated`:

```json
{
  "reply": "Done! I've scheduled 3 morning runs for you.",
  "calendarUpdated": true,
  "events": [
    { "title": "Morning Run", "startTime": "2026-05-12T00:00:00Z" },
    { "title": "Morning Run", "startTime": "2026-05-14T00:00:00Z" },
    { "title": "Morning Run", "startTime": "2026-05-16T00:00:00Z" }
  ]
}
```

`events` is `null` (not present) when `calendarUpdated` is `false`. Decode it as `[CreatedEvent]?`.

---

## 3. AI Coach — multi-tool conversations now work

**Problem.** If the AI needed to call two tools in one conversation turn (e.g. fetch your habits and then write calendar events), only the first tool call was executed. The AI would get stuck.

**Fix.** The server now loops up to 5 tool-call rounds per message before giving up. From iOS's perspective nothing changes — you still send one message and get one reply. The AI just handles more complex requests now.

---

## 4. AI Coach — conversation history

**Problem.** Every `POST /ai/chat` was a fresh context. The AI had no memory of what you said in the previous message.

**Fix.** The server now stores the last 20 messages per user in a database table (`ai_conversations`). Follow-up messages like "change the first one to 8am" now work.

**No iOS change needed.** The conversation is per-user on the server side. You just keep sending `{ "message": "..." }`.

---

## 5. AI Coach — timezone support (new requirement from Tai)

**Problem.** The AI was scheduling events in UTC regardless of the user's location. For Bangkok (UTC+7), "7am" was landing as `2026-05-10T07:00:00Z` (i.e. 2pm Bangkok time) instead of `2026-05-10T00:00:00Z`.

**Fix.** `POST /ai/chat` now accepts an optional `timezone` field:

```json
{ "message": "Schedule a run at 7am tomorrow", "timezone": "Asia/Bangkok" }
```

The server uses this timezone to anchor "today", compute weekday names, and tell the AI to convert local times to UTC when writing calendar events. If `timezone` is omitted, falls back to UTC.

**What to do on iOS:** Send the device timezone identifier with every chat message:
```swift
TimeZone.current.identifier  // e.g. "Asia/Bangkok"
```

---

## 6. AI Coach — weekday accuracy improvement

**Problem.** Gemini would sometimes schedule "Monday" on a Tuesday.

**Fix.** The system prompt now includes an explicit `Monday=2026-05-11, Tuesday=2026-05-12, ...` anchor for the next 14 days, computed fresh at request time. The AI has no excuse to get weekdays wrong now.

---

## 7. Habits — `PATCH /habits/:id` (new, for iOS edit sheet)

**What's there.** `PUT /habits/:id` already existed and handles partial updates (all fields optional). We've now also registered `PATCH /habits/:id` pointing at the same handler, so either verb works.

**Request body** (all fields optional):
```json
{
  "name": "Evening Run",
  "category": "fitness",
  "targetTime": "18:00",
  "description": "After work",
  "isActive": true,
  "frequency": "daily"
}
```

**Response:** same habit object as `GET /habits`.

---

## 8. Habits — frequency is now validated

**Problem.** `frequency` was a free-text string with no enforcement.

**Fix.** Only `"daily"`, `"weekly"`, `"monthly"`, `"custom"` are accepted. Anything else → 400 `"invalid frequency — valid values: daily, weekly, monthly, custom"`.

---

## 9. Habits — past logs can now be deleted

**Problem.** `DELETE /habits/:id/log` only removed today's log.

**Fix.** Accepts optional `?date=yyyy-MM-dd` query parameter:
```
DELETE /habits/:id/log?date=2026-05-07
```
Omitting `date` still defaults to today. Returns 404 if no log exists for that date.

---

## 10. Habits — premium gating

**Problem.** The `premium` role existed but no limits were enforced.

**Fix.** Free-tier users are limited to 5 active habits. The 6th `POST /habits` returns 403 `"Upgrade to premium to create more than 5 habits"`. Premium and admin users are unlimited.

---

## 11. Calendar — soft-deleted events can be restored

**New endpoint:** `POST /calendar/:id/restore`

Restores a soft-deleted event. Returns 200 with the restored event object. Returns 404 if the event doesn't exist or was never deleted.

---

## 12. Admin — user delete

**New endpoint:** `DELETE /admin/users/:id` (admin role required)

Soft-deletes the user. Returns 204. Returns 400 if you try to delete your own account, 404 if the user doesn't exist.

---

## 13. Pagination on list endpoints

**Breaking change** — `GET /habits`, `GET /calendar`, `GET /admin/users` no longer return bare arrays. Response shape is now:

```json
{
  "items": [ ...same objects as before... ],
  "metadata": { "page": 1, "per": 20, "total": 42 }
}
```

**Query params** (all optional):
- `?page=1` — 1-indexed, defaults to 1
- `?per=20` — items per page, defaults to 20, capped at 100

**What you need to update on iOS:** Anywhere you decode `[HabitResponse]`, `[CalendarEventResponse]`, or `[AdminUserResponse]` from these endpoints, unwrap `.items` from the new envelope instead.

---

## Confirmed — no iOS changes needed

**`GET /dashboard`** already returns exactly the shape you described:
```json
{
  "user": { "id": "...", "name": "Taro", "role": "free" },
  "overallStreak": 5,
  "habitsSummary": { "total": 4, "active": 4, "completedToday": 2 },
  "todayHabits": [...]
}
```

**`GET /habits/:id/stats`** returns exactly:
```json
{
  "habitID": "...",
  "currentStreak": 8,
  "longestStreak": 14,
  "completionRate": 0.857,
  "weekGrid": [true, true, false, true, true, true, false]
}
```
Field names match. `weekGrid` is Mon–Sun for the current UTC week. `completionRate` is over the last 30 days.

---

## Summary table

| Area | What changed | iOS action needed |
|---|---|---|
| Date encoding | ISO 8601 everywhere | Remove any numeric-date workarounds |
| Auth logout | Actually invalidates token | Re-login after first deploy |
| AI chat response | `events` field added | Decode `[CreatedEvent]?` from response |
| AI chat request | `timezone` field added | Send `TimeZone.current.identifier` |
| AI context | Conversation history | Nothing |
| Habits edit | `PATCH /habits/:id` added | Use PATCH (or PUT — both work) |
| Habits create | `frequency` validated | Ensure only valid values sent |
| Habits unlog | `?date=` param added | Optional — use if you need past unlog |
| Habits create | 5-habit limit for free tier | Show upsell on 403 |
| Calendar restore | `POST /calendar/:id/restore` | Wire up if you want restore UI |
| Admin | `DELETE /admin/users/:id` | Wire up in admin panel |
| List endpoints | Paginated — bare array → `Page<T>` | **Must update decoders** |
| Dashboard | Already correct | Nothing |
| Stats | Already correct | Nothing |
