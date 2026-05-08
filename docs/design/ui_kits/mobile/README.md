# HabitFlow AI · Mobile UI Kit

A high-fidelity recreation of the HabitFlow AI mobile app — a habit-tracking + AI-coaching companion. This kit is for designing and prototyping new flows with pixel-fidelity components.

## Files

| File | What it is |
|---|---|
| `index.html` | Click-thru demo: switch between Today, Habits, Coach, Calendar, Profile, Login |
| `ios-frame.jsx` | iPhone bezel + status bar |
| `Primitives.jsx` | `C` (color tokens), `CAT` (category palette), `Icon`, `StyleInjector`, `TabBar` |
| `LoginView.jsx` | Email/password + Google sign-in |
| `TodayView.jsx` | Hero greeting, streak/progress, ritual list, AI insight |
| `HabitsView.jsx` | Bento-grid of all rituals + add card |
| `CoachView.jsx` | AI chat — bubbles, suggestion chips, scheduled-events card |
| `CalendarView.jsx` | Week view with manual / AI / Google event coloring |
| `ProfileView.jsx` | Avatar card, stats trio, settings list |

## Conventions

- **Component scope.** Each `.jsx` is its own Babel script — exports go on `window` at the bottom of the file. Shared tokens live on `window.HF`.
- **Style names are unique** (`hf-screen`, `hf-page-hero`, `hf-pulse`) to avoid collisions.
- **No real persistence.** State is `useState` only — refresh resets everything. That's the point of a kit.
- **Icons.** Material Symbols Outlined via Google Fonts CDN. Pass `fill` to swap to filled glyphs (used for active tab icons + emphasis like the streak flame).
- **Type.** Plus Jakarta Sans (display, italic ExtraBold for hero pages — "Your Oasis." "This Week.") + Be Vietnam Pro (body).

## Visual signatures

- **Pulsing flame.** The streak flame has a subtle 2s scale pulse (`.hf-pulse`). It's the only ambient motion in the app — keep it scarce.
- **Tropical Punch palette.** Orange `#FF8243` primary, teal `#069494` tertiary, pink `#FFC0CB`, yellow accent `#FCE883`. Cream `#FFF9F5` background.
- **Italic page heroes.** "Your Oasis." "This Week." "Profile." — heavy italic with a period, not a colon.
- **Squared inner corner on chat bubbles.** User bubbles flip the corner on the right; AI bubbles on the left. 4px on the tail corner, 16px elsewhere.
- **Category-colored tiles.** Each habit's icon sits in a soft pastel chip (health=green, fitness=orange, mindfulness=purple, productivity=blue, learning=yellow, social=pink). The chip color matches the habit's category badge.

## What's omitted (intentional)

- Real auth, real persistence, real Google Calendar sync
- Onboarding flow, push notifications, deep-link handling
- Habit-create modal (the `+` buttons no-op)
- Detail screens for individual habits

These are scaffolding work for a real app — the kit's job is to nail the look and feel.
