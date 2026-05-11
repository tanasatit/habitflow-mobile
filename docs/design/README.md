# HabitFlow Design System — *Tropical Punch*

A design system for **HabitFlow**, an AI-powered personal habit tracker. HabitFlow combines a daily checklist, streak tracking, a visual calendar, and a Gemini-powered AI Coach that turns plain-English plans into scheduled events.

---

## Sources

| Source | URL / Path | Notes |
|---|---|---|
| Mobile repo (this brief) | `tanasatit/habitflow-mobile` | Greenfield Swift 6 + SwiftUI iOS rewrite. Backend (Vapor) and Phase-1 plan only — no UI in repo yet. |
| Web repo (visual source-of-truth) | `tanasatit/HabitFlow` | The shipped Next.js 14 + Tailwind v4 web app. **All visual tokens, components, and screen layouts in this design system are lifted from here.** |
| Theme name | "Tropical Punch" | Coined in `docs/prp/PRP-001-phase1-mobile-foundation.md` §2.2. Defined in `frontend/src/app/globals.css`. |

The mobile rewrite is **stylistically identical** to the web app — same palette, same iconography (Material Symbols), same hero italic display type, same rounded cards. The mobile UI kit in this design system mirrors the five-tab structure from PRP-001: Today · Habits · Calendar · Coach · Profile.

---

## Products

HabitFlow ships in two surfaces:

1. **HabitFlow Web** (Next.js + Go) — production. Sidebar nav, 12-col bento grids, full feature set (Free/Premium/Admin).
2. **HabitFlow Mobile** (SwiftUI + Vapor) — Phase-1 greenfield rewrite. Tab-bar, single-column scroll, no Google Calendar sync. **Design covered by the `mobile` UI kit in this system.**

Three user roles enforced everywhere: **Free** (3 habits, no AI), **Premium** (unlimited + AI Coach + Calendar), **Admin** (user management).

---

## Index

| File | What's in it |
|---|---|
| `README.md` | This file — context, content, visual, iconography rules. |
| `SKILL.md` | Agent-Skill manifest so this system is portable to Claude Code. |
| `colors_and_type.css` | All CSS variables — palette, type families, semantic scale, radii, spacing, shadow, motion. |
| `fonts/` | Webfont references (Plus Jakarta Sans + Be Vietnam Pro via Google Fonts). |
| `assets/` | Logos, the favicon, and brand SVGs. |
| `preview/` | One HTML card per design-system concept — used by the Design System review tab. |
| `ui_kits/mobile/` | Hi-fi click-thru recreation of the Phase-1 mobile app: Login, Today, Habits, Calendar, Coach. |

---

## CONTENT FUNDAMENTALS — voice & copy

HabitFlow's voice is **warm, gently poetic, and second-person**. It treats habit-building as self-care, not productivity hustle. No drill-sergeant tone, no gamification slang.

| Rule | Yes ✓ | No ✗ |
|---|---|---|
| **Pronoun** | "you", "your" | "users", "the user" |
| **Page heroes** | "Your Oasis.", "Welcome back, Tai!" | "Habits Dashboard", "User Home" |
| **Habits called…** | "rituals" (in product copy) | "tasks", "todos" |
| **Streaks framed as…** | "day streak", "🔥 5" (with flame icon, never the emoji) | "5-day chain", "5x in a row" |
| **AI prompts** | "Plan my week", "Build a morning routine", "Review my progress" | "Execute schedule generation" |
| **Empty states** | "No rituals yet. Create your first ritual to start building better routines." | "You have 0 items." |
| **Success toast** | "Ritual created!", "Habit marked complete!" | "Operation succeeded." |
| **Error toast** | "Already completed for today.", "Invalid email or password." | "Error 409: duplicate." |
| **CTAs** | "Add Ritual", "Chat with AI Coach", "Sign In", "Create one" | "Submit", "OK", "Click here" |

**Casing.** Sentence case in body, **Title Case** on buttons (`Add Ritual`, `Sign In`). The page hero is the only place that uses a **trailing period as a flourish** (`Your Oasis.`).

**Typographic flair.** Page heroes are **italic, ExtraBold, Plus Jakarta Sans** — punchy and editorial. The first name in "Welcome back, **Tai**!" is colored `--color-primary`.

**Emoji.** Not used. Material Symbols (filled variant) replace emoji everywhere — `local_fire_department` for streaks, `auto_awesome` for AI, `checklist` for habits.

**No exclamation-point spam.** One per screen, max — usually on success ("Ritual created!").

**Numbers.** Tabular numerals on streak counters and percentages (`font-variant-numeric: tabular-nums`).

---

## VISUAL FOUNDATIONS

### Palette — "Tropical Punch"
Four-color brand built around a **warm cream background** (`#FFF9F5`) — never pure white. Primary is a saturated tropical orange; secondary is soft pink; tertiary is a deep teal that does the heavy lifting for "completion" and AI surfaces.

| Token | Hex | Usage |
|---|---|---|
| `--color-primary` | `#FF8243` | CTAs, streak flame, active nav, AI bubbles (user side) |
| `--color-secondary` | `#FFC0CB` | Soft accents, Google-source calendar events |
| `--color-tertiary` | `#069494` | Completion checkmarks, AI-source events, "view all" links |
| `--color-accent` | `#FCE883` | AI Insight cards (full-bleed yellow) |
| `--color-background` | `#FFF9F5` | App background — warm cream, never `#fff` |
| `--color-surface` | `#FFFFFF` | Cards, sheets, modals |
| `--color-on-background` | `#302E2C` | Body text — warm near-black |

Six **category accents** (health/fitness/mindfulness/productivity/learning/social) follow a Tailwind-style 100/700 bg/fg pair convention — soft tinted backgrounds with saturated text.

### Typography
**Two families.** `Plus Jakarta Sans` for headlines (400/500/700/800 + italic). `Be Vietnam Pro` for body (400/500/600/700). Material Symbols Outlined for icons.

The signature move: **page heroes are `italic font-extrabold`** Plus Jakarta with a trailing period (`Your Oasis.`, `Welcome back, Tai!`). Numbers — streak counters especially — are 6xl ExtraBold colored primary orange.

### Backgrounds & imagery
- **Solid warm cream** (`#FFF9F5`) — no gradients, no textures, no patterns.
- **No photography** in product chrome. Imagery only as user-uploaded avatars (circle, 2px primary border).
- **Modal backdrop:** `bg-black/40 backdrop-blur-sm`.
- **No full-bleed hero images.**

### Borders
Hairline `1px solid #E0DAD6` on every card. Borders, not shadows, are the primary card-separating device. Shadows appear only on hover (`shadow-md`) and on FABs (primary-tinted `--shadow-pop`).

### Corner radii
Generously rounded — the brand reads "soft and approachable":
- Inputs / pill buttons → `rounded-full` or `rounded-xl` (12px)
- Cards → `rounded-2xl` (24px)
- Icon squares → `rounded-xl` (12px)
- Chat bubbles → `rounded-2xl` with one corner squared (`rounded-tr-none` for user, `rounded-tl-none` for AI) — the "tail" trick.

### Cards
A standard card is: `bg-surface` + `border border-outline` + `rounded-2xl` + `p-5` or `p-6`. **No drop shadow at rest.** Hover: `shadow-md`. The bento HabitCard adds a thin tertiary progress bar absolutely-positioned along the bottom edge.

### Buttons
- **Primary:** filled `bg-primary text-white rounded-full px-5 py-2.5 font-semibold` — pill-shaped, hover drops opacity to 90%.
- **Secondary:** `bg-surface-variant text-on-surface-variant rounded-full` — also pill.
- **Tertiary text link:** plain `text-tertiary hover:underline`.
- **Icon button:** `p-1.5 rounded-full hover:bg-surface-variant`.
- **Send button** (chat): squared `rounded-xl`, **uppercase + tracking-widest** label.

### Animation
GSAP + Framer Motion in code; the system in tokens:
- `--ease-out` `cubic-bezier(0.16, 1, 0.3, 1)` — list reveals, 200ms
- `--ease-spring` `cubic-bezier(0.34, 1.56, 0.64, 1)` — checkmark pop, 400ms
- **Pulsing flame:** `scale [1, 1.05, 1]` over 2s, infinite easeInOut. Used on streak surfaces — this is the brand's signature motion (defined in PRP-001).
- **Whileтатtap on checkbox:** `scale [1, 1.3, 1]` — quick punch.
- Modal: fade + scale, 200ms.

### Hover & press
- **Hover on cards:** raise to `shadow-md`, no transform.
- **Hover on nav links:** `bg-surface-variant`.
- **Hover on chips:** border swaps to `border-primary`, text to `text-primary`.
- **Press / active:** `cursor-grabbing` on draggable events; tap-pulse on buttons.
- **Focus ring:** `outline: 2px solid var(--color-primary); outline-offset: 2px`.

### Layout
- Desktop sidebar nav with floating pill items (`mx-6 py-3 px-6 rounded-full`).
- Mobile (this system's UI kit): tab-bar bottom nav, 5 tabs, each screen scrolls a single column.
- Modals are `max-w-md` cards centered with backdrop blur.
- Padding rhythm: `p-6` md, `p-8` desktop on page roots; cards use `p-5`.

### Transparency & blur
- Backdrop blur (`backdrop-blur-sm`) on modal overlays.
- Tinted overlays on category icons (`bg-{cat}-100`).
- Streaming cursor in chat bubbles is `bg-tertiary/40 animate-pulse`.

### Shadows
Soft, neutral, low-opacity:
- `--shadow-sm` `0 1px 2px rgba(48,46,44,0.04)` — at-rest cards (rarely; usually borders only).
- `--shadow-md` `0 4px 12px rgba(48,46,44,0.06)` — hover.
- `--shadow-pop` `0 8px 24px rgba(255,130,67,0.18)` — primary-tinted, FABs/upgrade promos.

---

## ICONOGRAPHY

**HabitFlow uses Material Symbols Outlined exclusively** — loaded via Google Fonts, the same stylesheet for both web and (planned) mobile. Two variation states are used everywhere:

| Variation | When |
|---|---|
| `'FILL' 0` (outlined) | Default state — inactive nav items, secondary actions |
| `'FILL' 1` (filled) | Active nav, streak flame, completed checks, hero icons |

Toggle via `style={{ fontVariationSettings: "'FILL' 1" }}` in code — never use a different font, never mix outlined and filled icon families.

### Standard sizes
- Tab bar / nav rail: **20px** (`text-[20px]`)
- Inline meta (streak count): **14px**
- Card icon-square: **18px**
- Hero / streak: **48px** (the pulsing flame)

### Common symbols (mobile UI kit)

| Symbol | Used for |
|---|---|
| `dashboard` | Today tab |
| `checklist` | Habits tab |
| `auto_awesome` | AI Coach (sparkle) |
| `calendar_month` | Calendar tab |
| `person` | Profile tab |
| `local_fire_department` | Streak (always filled, always primary orange) |
| `favorite`, `fitness_center`, `self_improvement`, `work`, `school`, `people` | Habit categories (health, fitness, mindfulness, productivity, learning, social) |
| `smart_toy` | AI assistant avatar |
| `add` | Create FABs |
| `check`, `undo` | Habit completion toggle |
| `arrow_forward` | Inline link CTA |
| `admin_panel_settings` | Admin nav |

**Emoji and unicode icons are not used** — Material Symbols cover every icon need.

**Logo / brand mark.** HabitFlow uses a wordmark only (no separate icon mark in the web repo): the literal string `HabitFlow AI` set in italic ExtraBold Plus Jakarta, colored `--color-primary`. The mobile app icon and launch screen are listed as Day-6 polish in PRP-001 and have not yet been designed — the UI kit reuses the wordmark on the login screen and reserves the iOS app-icon slot for future.

---

## CAVEATS & SUBSTITUTIONS

- **Fonts.** Both **Plus Jakarta Sans** and **Be Vietnam Pro** are Google Fonts and are referenced via CDN — no `.ttf` files in `fonts/` because they don't need to be self-hosted to render correctly. If the system is exported to an offline environment, swap to the Google Fonts download zip.
- **Icon font.** Material Symbols is loaded via Google Fonts CDN. Same caveat as above for offline use.
- **Logo files.** The web repo only ships `favicon.ico` — no SVG/PNG marks. The wordmark `HabitFlow AI` is recreated as live text in the UI kit.
- **iOS app icon and launch screen** are not yet designed in either repo. Marked `TODO` in PRP-001 §5 Day 6.
- **The mobile repo (`habitflow-mobile`) has no SwiftUI code yet** — Phase 1 ends with Day-3 iOS skeleton not yet shipped at the time of writing. The mobile UI kit in this design system is therefore a **forward-looking design** based on the web app's visual language plus PRP-001's tab structure, not a code-perfect replica.
