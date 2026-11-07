# Focus and do not disturb

## 1. Purpose

Protect deep work. A focus session is a timed promise to yourself: the shell goes quiet, holds what
can wait, shows only a slowly filling ring, and tells you afterwards what waited. Do not disturb is the
same silence without a timer.

## 2. Focus session

### States

```
        start(d, intent)            time up              Break          break over
 idle ───────────────────► focusing ─────────► done ───────────► break ────────────► idle
   ▲                         │  ▲  │             │ Extend +10 → focusing
   │          Stop           │  │  │ Pause       │ Stop ─────────────────────────► idle
   └─────────────────────────┘  │  ▼             │
                                paused ──────────┘ (Resume → focusing; Stop → idle)
```

| State | Notch | Bar | Notifications |
|---|---|---|---|
| focusing | right slot: ring + minutes left | quiet (M-31b) | held, except critical, allowlist, timers, meeting activities |
| paused | right slot: ring (`ink.meta`) + `pause` glyph | normal | normal |
| done | toast-like card: "Focus done · 50 min" with Break 10 / +10 min / Stop; soft chime (`focus.sound`) | normal | summary toast follows: "7 notifications while you were focused" |
| break | right slot: ring in `ink.sec` + minutes left | normal | normal |
| break over | event: "Break over" with a "Start 50 min" button for 8 s | normal | normal |

### Starting

`Super+Shift+F` (or the clock's menu, the Deck tile, Today, Spotlight `focus 40 write report`) opens
the **focus picker** in the notch:

```
 ────╮                                              ╭────
     ╰──────────────────────────────────────────────╯
     │ ◎  What are you focusing on?                 │   field (optional intent), 40 high
     │    [ 25 ]  [ 50 ]  [ 90 ]  [ Custom… ]       │   segmented control, last choice selected
     │                          ↵ Start   Esc Cancel │
     ╰──────────────────────────────────────────────╯   420 × 132
```

`Enter` starts; `←/→` or `1–4` choose the duration; *Custom…* turns into a minutes field (5–240).
While a session runs, the same key opens the focus card with the keyboard (Stop focused; Enter
stops, `P` pauses, `+` adds 10 min).

### Rules
- The end time is absolute and stored in `~/.local/state/aptus/focus.json`, so a shell restart or a
  lock/unlock never changes it.
- Suspend: time keeps counting (it is wall-clock time). Resuming after the end time shows *done*.
- A meeting starting during focus still shows its compact activity; with `focus.endForMeetings` the
  session ends (logged as completed early) when the meeting starts.
- Manual DND set before the session stays as it was after the session ends.
- Locking the screen does not pause focus.

### Log and statistics

Every session appends to `~/.local/state/aptus/focus-log.jsonl`:
`{"start": "…", "end": "…", "planned_min": 50, "actual_min": 47, "intent": "…", "outcome": "completed|stopped|extended", "held": 7}`.
Today shows today's total against `focus.dailyGoal`; clicking the focus block expands a 7-day view:
seven bars (accent, today darker), totals in `ink.meta`, the current streak of days that met the goal.

## 3. Do not disturb

| Mode | Set by | Ends |
|---|---|---|
| Until off | Deck tile, `Super+Shift+D`, Spotlight | when turned off |
| For a time | tile menu, clock menu, Spotlight (`dnd 1h`, `dnd until 18:00`) | at that time |
| Scheduled | `dnd.schedule` (e.g. 22:00–07:00, off by default) | at the schedule's end |
| Implied by focus | a focus session | with the session |

While DND is on: the status cluster shows `do_not_disturb_on` (unless focus is running);
notifications follow the interruption policy ([05-interaction.md](../05-interaction.md) §8); when it
ends, one summary toast for what was held.

## 4. Quiet bar

The visual part of focus, also available alone (`Super+Shift+B`, Spotlight "Quiet bar"): window
title, tray, date and non-critical status collapse (M-31b). Hovering the bar for 600 ms shows them
again until the pointer leaves.

## 5. Data and settings

`Focus` service (state machine above, one `Timer` at 1 Hz only while focusing or on break),
`Notifications` service (hold queue). Settings: `focus.durations` (25, 50, 90), `focus.default` (50),
`focus.breakMinutes` (10), `focus.autoBreak` (false), `focus.sound` (true), `focus.dailyGoal` (240),
`focus.endForMeetings` (false), `focus.quietBar` (true), `dnd.schedule` (off),
`notifications.allowlist`.
