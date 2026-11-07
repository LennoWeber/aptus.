# aptus v2: design specification

This folder is the full design for **aptus v2**, a new desktop shell for the **Hyprland** session on
Lenno's ThinkPad P1 Gen 2. It replaces aptus v1 completely. Nothing in here is code. It is the plan
every line of code will be written against.

**Two sessions, one home.** Umbriel keeps Noctalia, exactly as it is today. Hyprland gets aptus. The
look, the shell and the theming of each session never reach the other one. How that is guaranteed is
in [02-isolation.md](02-isolation.md), and it is the most important document here.

## How to read this

| # | Document | What it answers |
|---|---|---|
| 01 | [Vision](01-vision.md) | What aptus v2 is for, the principles, what was taken from the inspiration and what was left out |
| 02 | [Session isolation](02-isolation.md) | How Hyprland gets aptus's look while Umbriel stays byte-for-byte Noctalia's |
| 03 | [Visual language](03-visual-language.md) | Colour, material, type, icons, geometry, spacing, states: every token with its value |
| 04 | [Motion](04-motion.md) | Durations, curves, springs, choreography rules, and every animation in the shell |
| 05 | [Interaction model](05-interaction.md) | Where surfaces come from, focus rules, the Esc ladder, the full keymap, pointer, multi-monitor |
| 06 | [Surfaces](surfaces/) | One document per surface: anatomy, states, interactions, timelines, data, edge cases |
| 07 | [Architecture](07-architecture.md) | Processes, startup, QML structure, services, surface manager, IPC, persistence, performance |
| 08 | [Theming pipeline](08-theming.md) | Palette resolution, the renderer, every app target and how it reloads |
| 09 | [Hyprland profile](09-hyprland.md) | The exact Lua blocks: look, animations, rules, binds, environment, autostart |
| 10 | [Settings reference](10-settings.md) | Every setting key with type, default, range and where it shows |
| 11 | [Roadmap](11-roadmap.md) | Probes to run first, implementation phases, acceptance tests, migration from v1 |
| 12 | [Decisions](12-decisions.md) | Decision log with reasons, and Lenno's answers to the open questions (2026-11-07) |

Surfaces, in [surfaces/](surfaces/):
[frame and bar](surfaces/bar.md) ·
[notch](surfaces/notch.md) ·
[spotlight](surfaces/spotlight.md) ·
[switcher and overview](surfaces/overview.md) ·
[deck](surfaces/deck.md) ·
[today](surfaces/today.md) ·
[focus](surfaces/focus.md) ·
[capture](surfaces/capture.md) ·
[session, lock and polkit](surfaces/session.md) ·
[wallpaper and gallery](surfaces/wallpaper.md) ·
[settings app](surfaces/settings.md) ·
[keys cheatsheet and jot](surfaces/keys-jot.md)

Probe results are recorded in `probes.md` once they are run ([11-roadmap.md](11-roadmap.md) §1).

## Words used everywhere

| Word | Meaning |
|---|---|
| **Frame** | The thin band around the whole screen, drawn by aptus. The bar is its top edge. Every docked surface grows out of it. |
| **Bar** | The top edge of the frame, 32 px, holding workspaces, the active window, the notch and the status cluster. |
| **Notch** | The centre of the bar. At rest it is the clock. It bulges downward into toasts, OSD, live activities, Spotlight, Today and other sheets. |
| **Bulge** | The part of a surface that hangs below the bar, joined to it by coves. |
| **Cove** | A concave corner (an inverse radius) where a surface meets the frame, so the two read as one piece. |
| **Drawer** | A docked surface that grows out of an edge or corner: Deck, Today, Spotlight, and the other sheets. |
| **Menu** | A small floating list anchored to a control (tray menus, context menus). Menus do not dock. |
| **Live activity** | Something happening now that the notch shows compactly: media, timer, focus session, recording, upcoming meeting, progress. |
| **Toast** | A notification shown briefly in the notch. |
| **Ink** | A text colour level: main, sec, meta, faint. Text is ranked by ink, never by opacity. |
| **Ground** | The material colour surfaces are made of. |
| **Wash** | The ink laid over the ground at a small amount, for hover, current and pressed states. |
| **Lease** | aptus's temporary, journaled takeover of a file or key that both sessions share, given back when the Hyprland session ends. |
| **Slot** | One leased item: a file, a set of INI sections, or one dconf key. |
| **Probe** | A fact that must be checked on the laptop before the part that depends on it is built. Every probe has a fallback. |

## Status

Design complete, not implemented. The implementation plan is in [11-roadmap.md](11-roadmap.md) and
follows the `phasen-entwicklung` workflow. Every open question was answered on 2026-11-07
([12-decisions.md](12-decisions.md) §2). The brief for the implementing agent is
[handoff-prompt.md](handoff-prompt.md).
