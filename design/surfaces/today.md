# Today

## 1. Purpose

Time, plans and what arrived, side by side: the day's agenda next to the notifications, plus the
quick notes (jot inbox), the focus session and the weather. Opened from the clock, so "what is
happening today" lives where the time is.

## 2. Anatomy

```
 ──────────────╮                                                              ╭──────────────
               ╰──────────────────────────────────────────────────────────────╯
               │ Saturday, 7 November                         ☁ 9° · Rain 16:00│  header 44
               │                                                               │
               │ ┌ Next ───────────────────────────┐  Notifications   Clear all│
               │ │ Stand-up                 in 9 min│  ▢ Thunderbird · 3       │  left column 352
               │ │ 14:00–14:15 · meet.google.com    │    Invoice November      │  right column 352
               │ │ [ Join ]                         │    Re: aptus v2 design   │  gutter 24
               │ └──────────────────────────────────┘  ▢ zen · 1               │
               │ Today                                    Download finished    │
               │ 09:30  ● Deep work                  ✓     …                   │
               │ 14:00  ● Stand-up                         ─────────────────── │
               │ 16:00  ● Review with Mia                  Inbox            ＋ │
               │ Tomorrow                                  ☐ buy milk          │
               │ 10:00  ● Dentist                          ☐ call the bank     │
               │                                           Idea: notch timer…  │
               │   November 2026        ‹  ›               ─────────────────── │
               │ Mo Tu We Th Fr Sa Su                      ◔ Focus  1 h 40 today│
               │ …month grid, today ringed, dots on days     [ Start 50 min ]   │
               │   with events                                                 │
               ╰───────────────────────────────────────────────────────────────╯
                                         width 760, padding 16
```

- Bulge from the notch, width 760, height = the taller column, at most monitor height − 32 − 48;
  each column scrolls on its own if needed.
- Left column (*time*): Next, agenda (today and tomorrow), month.
- Right column (*inbox*): notifications, jot inbox, focus.
- Header: the full date in `heading`; weather on the right (`body`, `ink.sec`): current temperature,
  condition glyph, and the next notable change ("Rain 16:00", "Clear tonight"); click opens a
  12-hour strip under the header (hour, glyph, temperature) until clicked again.

## 3. Next

A `raised` card (radius 12) for the next event that has not ended, within the next 12 hours:
title (`title`), relative time ("in 9 min", "now · 12 min left", "at 16:00"), time range, location
or meeting-link host. A **Join** primary button when the event has a meeting link (Google Meet,
Zoom, Teams, Jitsi, Webex, found in location, description or URL); otherwise no button. With no
event in the next 12 hours: "Nothing else today" in `ink.meta`, and the card shrinks to one line.

## 4. Agenda

- "Today" then "Tomorrow" groups. Rows (32 high): start time (tabular, `ink.meta`), a 6 px dot in the
  calendar's colour (mapped to the nearest accent/neutral so it stays legible), title (`body`),
  a `check` glyph on past events (the row in `ink.faint`).
- The running event: `current` wash and a 2 px progress line along its bottom (`linear`, updates each
  minute).
- All-day events at the top of their group as one-line chips.
- Click: a detail popover inside the column (title, time, location, attendees count, description
  first 6 lines, Join, Copy link, Open in calendar web UI if the source gives a URL). Esc closes it.

## 5. Month

- Mini month (rows 28 high), Monday first, week numbers in `ink.faint` on the left
  (`today.weekNumbers`), today ringed in accent, days with events get a 4 px dot.
- Click a day: the agenda shows that day (the group title becomes the date, with a "Back to today"
  quiet button); `‹ ›` change month; `Home` returns to today.

## 6. Notifications

- Grouped by app: app icon 20, app name, count; the newest 3 of each group visible, "Show 5 more"
  expands. Groups ordered by their newest notification.
- Row: title (`bodyStrong`), body (`body`, 2 lines), time ("now", "5 min", "14:02", "Yesterday"),
  image thumbnail 40 if any, action buttons on hover/selection, ✕ on hover.
- Unread notifications have a 6 px `ink.sec` dot before the title; opening Today marks those
  *visible* as read after 1.5 s (so a glance counts as reading, a quick open-close does not).
- **Clear all**: removes everything except notifications marked `resident`; the list animates out
  top to bottom (15 ms stagger).
- Held notifications (during DND/focus) appear normally, with "Held during focus" as a group subtitle
  until opened.
- Empty: glyph `notifications` + "No notifications".
- History: the last 200 notifications persist across shell restarts in
  `~/.local/state/aptus/notifications.json`; images are copied into `~/.cache/aptus/notif/` so
  they survive the sending app clearing its temp files (raw `image-data` hints have no file: the
  toast shows them, the history keeps no image). Notifications older than 7 days are dropped.
  Read-back records get ids of their own (the server's ids start at 1 again with every shell
  start), so a new notification never replaces an old record; after a reload that kept the
  server's notifications (`keepOnReload`, development runs only) their records keep their ids.

## 7. Agenda data

- Sources: any number of calendars in `~/.config/aptus/calendars.json`:
  `[{ "name": "Work", "url": "https://…/basic.ics", "colour": "sky" }, { "name": "Local", "path": "~/Calendars/me.ics" }]`.
  The file is created with mode 0600 because private ICS addresses are secrets; the settings window
  edits it.
- `aptus-agenda` (Python, `python3-icalendar` + `python3-dateutil`, both in Fedora) fetches each URL
  every 10 minutes (and on demand from the Today header's refresh, and on resume from suspend), with
  `If-None-Match`/`If-Modified-Since`, a 15 s timeout, and expands recurrences (RRULE, RDATE, EXDATE,
  overridden instances via RECURRENCE-ID) for −1 to +60 days into
  `~/.local/state/aptus/agenda.json`. Times are converted to the local zone. The shell watches that
  file.
- Offline or failing source: its last good data stays, Today's header shows a quiet "Work calendar
  last updated 2 h ago" line under the date.
- Reminders: aptus itself (not notify-send) raises the meeting live activity 10 minutes before start
  (`calendar.remindBefore`) and a toast at start (respecting the interruption policy). Events with
  their own VALARM use that offset instead.

## 8. Jot inbox

The quick-notes file (`jot.file`, default `~/Notes/inbox.md`) shown as rows: `- [ ] text` as a
checkbox row, `- [x] text` struck through in `ink.faint`, plain lines as notes. Newest first, 8
visible, "Open inbox" opens the file in the default editor. Clicking a checkbox toggles it in the
file. `＋` opens Jot ([keys-jot.md](keys-jot.md)). Hovering a row shows ✕ (delete the line).

## 9. Focus block

Today's focused time ("1 h 40 today"), a ring with today's progress against `focus.dailyGoal`
(default 4 h), and a primary button: **Start 50 min** (or the remaining time and Stop while a session
runs). Details in [focus.md](focus.md).

## 10. Keyboard

`Tab` switches columns; `↑ ↓` moves within the column across its sections; `Enter` opens/acts
(Join, default action of a notification, toggle a todo); `Delete` dismisses a notification or deletes
a jot line; `Ctrl+Delete` clears the notification group; `J` opens Jot; `F` starts/stops focus;
`←/→` in the month change day; `Esc` closes a popover, then Today.

## 11. Motion

M-20: the clock travels into the heading (shared element), the bulge grows to 760 × H, the columns fade
in 60 ms / 100 ms. Close reverses; the heading travels back into the clock. M-21 for dismissals.

## 12. Edge cases

- No calendars configured: the left column shows the month and a one-line "Add a calendar" quiet
  button (opens Settings › Today & calendar) instead of Next and the agenda.
- An event spanning midnight: shown in both days with "continues" / "from yesterday".
- Hundreds of notifications from one app: the group shows 3 and "Show 197 more" loads in pages of 20.
- Time zone change (travel): agenda re-renders on the next tick; `aptus-agenda` re-expands.
- Today opened on a second monitor narrower than 900 px: one column, inbox under the time column.

## 13. Settings

`today.weekNumbers`, `calendar.sources` (via `calendars.json`), `calendar.remindBefore`,
`calendar.refreshMinutes`, `weather.location`, `weather.units`, `jot.file`, `focus.dailyGoal`,
`notifications.historyDays`, `notifications.historyMax`. Defaults in
[10-settings.md](../10-settings.md).
