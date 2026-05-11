# Known Limitations — Implementation Design
**Date:** 2026-05-09  
**Branch:** api/calendar-ai-admin  
**Scope:** All 10 known limitations from `docs/api-reference.md` + 1 blocking bug fix

---

## 0. Bug Fix: Date Format Mismatch (Blocker)

**Problem:** `configure.swift` has no custom `ContentConfiguration`. Vapor's plain `JSONEncoder/JSONDecoder` defaults encode/decode `Date` as a Swift reference-date `Double`, not ISO 8601 strings. The API spec promises ISO 8601. iOS sends ISO 8601 strings → Vapor returns 400 on `POST /calendar` (and any endpoint receiving dates from iOS).

**Fix:** Add to `configure.swift` before `try routes(app)`:
```swift
let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
app.content.use(encoder: encoder, for: .json)
app.content.use(decoder: decoder, for: .json)
```

Both sides change consistently, so existing tests continue to pass.

---

## 1. Auth: JWT Logout Denylist

**Limitation:** Stateless JWTs — logout does not invalidate the token.

**Design:**

- **New model** `RevokedToken`: `id` (UUID PK), `jti` (String, unique index), `expiresAt` (Date).
- **New migration** `AddRevokedTokens`: creates `revoked_tokens` table + unique index on `jti`.
- **`UserPayload` change:** Add `jti: String` claim (generated as `UUID().uuidString` at login/register). The JWT now carries a stable, unique identifier.
- **`AuthController.logout`:** `logout` is not in the protected group, so manually decode via `req.jwt.verify(token, as: UserPayload.self)` (wrapped in `guard let` with `try?`). If no valid token is present, return 204 gracefully. If valid, save `RevokedToken(jti: payload.jti, expiresAt: payload.exp.value)` and return 204.
- **`JWTAuthenticator` change:** After verifying the JWT signature, query `RevokedToken` for the `jti`. If a row exists → throw `Abort(.unauthorized, reason: "token has been revoked")`.
- Register migration in `configure.swift` after `CreateCalendarEvent`.
- Stale rows (past `expiresAt`) accumulate harmlessly at demo scale.

---

## 2. AI Coach: Multi-Tool Round-Trip Loop

**Limitation:** One function-call round-trip max.

**Design:** Replace the single function-call branch in `AICoachService.chat` with a `while` loop (max 5 iterations):

```
loop:
  call Gemini with current contents
  if response has functionCall:
    execute function, append result to contents
    calendarUpdated |= (function was write_calendar && events created)
    collect any created events
    continue
  else:
    return text reply
```

Exit when no function call is returned or after 5 iterations. `calendarUpdated` is `true` if *any* iteration triggered `write_calendar` with results.

---

## 3. AI Coach: Conversation History

**Limitation:** Each `/ai/chat` is a fresh context — no memory of prior messages.

**Design:**

- **New model** `AIConversation`: `id` (UUID PK), `userID` (UUID FK → users, unique), `messages` (JSON column storing `[[String: String]]` array of `{"role": "user"|"model", "text": "..."}` objects), `updatedAt` (Timestamp on update).
- **New migration** `CreateAIConversation`: creates table + unique index on `user_id`.
- **`AICoachService.chat`:**
  1. Load (or create) the user's `AIConversation` row.
  2. Decode stored messages; prepend them to `contents` before sending to Gemini.
  3. After the full exchange (post-loop), append the new user message and model reply to the stored list.
  4. Cap at last **20 messages** before saving to bound context size.
  5. Save updated row.
- Register migration after `AddRevokedTokens`.

---

## 4. AI Coach: Weekday Accuracy Improvement

**Limitation:** Gemini sometimes schedules the wrong weekday.

**Design:** Extend the system instruction to include explicit weekday→date anchors for the next 14 days, computed at request time:

```
Today is 2026-05-09 (Saturday) UTC.
Upcoming dates: Sunday=2026-05-10, Monday=2026-05-11, Tuesday=2026-05-12,
Wednesday=2026-05-13, Thursday=2026-05-14, Friday=2026-05-15,
Saturday=2026-05-16, Sunday=2026-05-17, Monday=2026-05-18, ...
Use ISO8601 UTC for all calendar event times.
```

Generated dynamically in `AICoachService` using `Calendar` + `DateFormatter`.

---

## 5. AI Coach: `events` Field in ChatResponse (iOS Contract)

**Requirement from Tai:** Response shape must include `events?: [{ title, startTime }]` when `calendarUpdated: true`.

**Design:**

- **`ChatResponse` DTO:** Add `var events: [CreatedEventResponse]?`.
- **New DTO** `CreatedEventResponse`: `let title: String`, `let startTime: Date` (encoded as ISO 8601).
- **`AICoachService.chat`:** Accumulate created `CalendarEvent` objects across loop iterations; return them alongside `(reply, calendarUpdated)`.
- `events` is `nil` when `calendarUpdated` is `false`.

---

## 6. Habits: Frequency Enum Validation

**Limitation:** `frequency` is free-text — no enforcement.

**Design:** Add a `HabitFrequency` enum:
```swift
enum HabitFrequency: String, Codable, CaseIterable {
    case daily, weekly, monthly, custom
}
```

Validate in `HabitController.create` and `update`: if the provided string isn't a valid case, return 400 `"invalid frequency — valid values: daily, weekly, monthly, custom"`. No migration needed — column stays `varchar`.

---

## 7. Habits: Past Log Deletion

**Limitation:** Logs can only be un-logged for today (UTC).

**Design:** Change `DELETE /habits/:id/log` to accept an optional `?date=2026-05-07` query param (UTC date, `yyyy-MM-dd` format). If omitted, defaults to today. Parse with a `DateFormatter`, compute UTC day bounds, find and hard-delete that day's log. Error: 404 if no log found for that date.

---

## 8. Calendar: Event Restore

**Limitation:** Soft-deleted events are permanently hidden — no restore endpoint.

**Design:** Add `POST /calendar/:id/restore` to `CalendarEventController`:

- Query with `.withDeleted()` to find soft-deleted events.
- Verify ownership (403 if not owner).
- Set `event.deletedAt = nil`, call `event.update(on: req.db)`.
- Return 200 with the restored `CalendarEventResponse`.
- Errors: 403 · 404.
- Register route in `boot`: `protected.post(":eventID", "restore", use: restore)`.

---

## 9. Roles: Premium Feature Gating

**Limitation:** `premium` role exists but no gating is implemented.

**Design:** Gate habit creation at 5 habits for `free` users. In `HabitController.create`:

```swift
if payload.role == .free {
    let count = try await Habit.query(on: req.db)
        .filter(\.$user.$id == userID)
        .filter(\.$isActive == true)
        .count()
    guard count < 5 else {
        throw Abort(.forbidden, reason: "Upgrade to premium to create more than 5 habits")
    }
}
```

No migration needed. `UserPayload` already carries `role`.

---

## 10. Admin: User Delete

**Limitation:** No user delete endpoint.

**Design:** Add `DELETE /admin/users/:id` to `AdminController`:

- Parse `userID` from path.
- Guard: return 400 if `userID == payload.userID` (prevent self-delete).
- Find user or 404.
- Soft-delete via `user.delete(on: req.db)`.
- Return 204.

---

## 11. Pagination

**Limitation:** No pagination on list endpoints.

**Design:** All three list endpoints gain optional `?page=1&per=20` query params. Default: `page=1`, `per=20`, max `per=100`.

Response shape changes from a bare array to a `Page<T>` envelope:
```json
{
  "items": [...],
  "metadata": { "page": 1, "per": 20, "total": 42 }
}
```

Affected endpoints: `GET /habits`, `GET /calendar`, `GET /admin/users`.

**⚠️ Breaking change for iOS** — coordinate with Tai before merging. Existing tests for these endpoints will need updating.

New shared DTOs:
```swift
struct PageMetadata: Content { let page: Int; let per: Int; let total: Int }
struct Page<T: Content>: Content { let items: [T]; let metadata: PageMetadata }
```

---

## Implementation Order

1. Bug fix: ISO 8601 content config (unblocks Tai immediately)
2. AI `events` field in ChatResponse (iOS contract, blocker)
3. JWT denylist (new model + migration)
4. AI conversation history (new model + migration)
5. AI multi-tool loop
6. AI weekday accuracy
7. Habit frequency validation
8. Past log deletion
9. Calendar restore
10. Premium gating
11. Admin user delete
12. Pagination (coordinate with Tai first)
