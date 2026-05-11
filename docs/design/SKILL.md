---
name: habitflow-design
description: Use this skill to generate well-branded interfaces and assets for HabitFlow, the AI-powered habit-tracking product (Tropical Punch theme). Contains essential design guidelines, colors, type, fonts, assets, and a mobile UI kit for prototyping.
user-invocable: true
---

Read the `README.md` file within this skill, and explore the other available files.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out and create static HTML files for the user to view. If working on production code, you can copy assets and read the rules here to become an expert in designing with this brand.

If the user invokes this skill without any other guidance, ask them what they want to build or design, ask some questions, and act as an expert designer who outputs HTML artifacts _or_ production code, depending on the need.

## Quick map

- `README.md` — full system: voice, palette, type, motion, iconography, caveats.
- `colors_and_type.css` — all CSS variables (palette, type, radii, spacing, shadow, motion).
- `assets/` — favicon and brand SVGs.
- `preview/` — one HTML card per concept (used by the design-system review tab; useful for reference snippets).
- `ui_kits/mobile/` — hi-fi click-thru iPhone recreation: Login, Today, Habits, Coach, Calendar, Profile. Components are split per-screen so you can lift just the parts you need.

## Two non-negotiables when designing for HabitFlow

1. **Habits are called "rituals"** in product copy — never "tasks" or "todos". Page heroes are **italic ExtraBold Plus Jakarta** with a trailing period (`Your Oasis.`).
2. **The flame (`local_fire_department`) is sacred.** Always Material Symbols, always filled, always primary orange `#FF8243`, often gently pulsing (2s scale 1↔1.06). Never substitute an emoji.
