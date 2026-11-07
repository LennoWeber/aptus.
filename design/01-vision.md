# 01 · Vision

## In one sentence

aptus v2 is a calm, warm, keyboard-first shell in which the whole desktop is **one continuous
frame**: every surface grows out of it, the centre of the top edge is a **notch** that tells you
what is happening now and turns into whatever you ask for, and nothing moves unless it explains
where something came from.

## Who it is for, and on what

| | |
|---|---|
| Person | Lenno: builds software, works in terminals and the browser, lives on the keyboard, cares about how things look and feel |
| Machine | Lenovo ThinkPad P1 Gen 2: i7-9750H, Intel UHD 630 + NVIDIA Quadro T1000 (hybrid), 30 GiB RAM, battery |
| Screens | eDP-1 1920×1080 @ 60 Hz, scale 1. Sometimes DP-1 1920×1080 to the right, sometimes HDMI-A-1 |
| Input | Built-in keyboard (German layout), TrackPoint, touchpad, Logitech MX Keys S. **No touchscreen.** |
| System | Fedora 44, Hyprland 0.57.1 with Lua config, Quickshell 0.3.2 on Qt 6.11.2 |
| Other session | Umbriel + Noctalia v5 + Noctalia greeter. Must not change. |

Design for 1920×1080 at scale 1 first. Every size in this spec is in logical pixels at scale 1.
The shell must still work at scale 1.25 and 1.5 and on a second monitor of a different size.

## Goals

1. **Productivity first.** Everything the shell offers is reachable from the keyboard in at most two
   keystrokes, and from the pointer in at most two clicks. One command surface (Spotlight) reaches
   everything else.
2. **Calm.** At rest the screen shows the frame, the clock, the workspaces and only the status that
   asks for attention. No perpetual animation, except the red recording dot.
3. **Beautiful by construction.** One material, one type family, one colour meaning, concentric
   corners, motion with a reason. The beauty comes from consistency, not decoration.
4. **Fast.** A hotkey shows its first frame in under 50 ms. Spotlight answers in-memory searches in
   under 16 ms. Idle CPU under 0.5 %.
5. **Isolated.** Hyprland looks like aptus; Umbriel looks like Noctalia. Logging out of one and into
   the other always restores the other's look completely, including after a crash.
6. **Never lose work.** Logout, restart and shutdown close windows gracefully and stop if an app asks
   to save. Locking can never fail open.

## Non-goals

- No dock. Pinned apps live in Spotlight's empty state and in keybinds. (A dock costs a screen edge
  and duplicates the launcher; see [12-decisions.md](12-decisions.md), D-04.)
- No desktop widgets (clock, cava, stats on the wallpaper). The wallpaper is a picture, not a board.
- No touch or tablet mode. The ThinkPad has no touchscreen.
- No wallpaper-derived full palettes (matugen-style). The palette is curated and contrast-checked;
  the wallpaper may only suggest the accent hue.
- No AI chat surface in v2. Spotlight can hand a query to the terminal (`claude`) as a command.
- No theming of the login greeter. The greeter is shared by both sessions and stays Noctalia's.
- No machine-wide settings that would leak into Umbriel (battery charge thresholds, logind lid
  policy, system packages that Noctalia's hooks react to). See [02-isolation.md](02-isolation.md).

## Principles

These decide every case this spec does not mention.

1. **One body.** The frame, the bar and every drawer are one material. A surface that comes to you
   grows out of the frame with coves; it does not float as a card. Only menus and tooltips float.
2. **Things come from where they belong.** About *now* and *intent* (time, notifications, search,
   switching): the notch. About *the machine* (network, sound, power): the top-right corner. About
   *spaces* (workspaces, windows): the left of the bar, opening into the overview.
3. **Colour means something.** Accent = current, on, the default action. Amber = needs attention.
   Red = recording, muted, failing, destructive. Everything else is neutral ink on ground. Colour
   never carries meaning alone; a shape or a word always comes with it.
4. **Text is ranked by ink, never by opacity.** Four inks: main, sec, meta, faint.
5. **Motion explains.** A surface grows from where it lives and returns there. Motion is
   interruptible and never makes you wait: input is accepted from the first frame.
6. **Quiet until it matters.** Status appears when it needs you (low battery, mic in use, a meeting
   in 10 minutes) and leaves when it does not.
7. **Every surface has a way out.** Esc, and a click outside. Esc always steps back one level.
8. **Windows never move for the shell.** Reserved space never changes when surfaces open, close or
   peek.
9. **Nothing opens under a passing pointer.** Hover shows a wash or a tooltip. Three deliberate
   exceptions, each needing the pointer to *rest*, none taking the keyboard: a live activity in the
   notch expands after 300 ms; the quiet bar shows its hidden items after 600 ms; over a fullscreen
   window, pushing against the top edge for 400 ms brings the bar back.
10. **Defaults are the product.** Every setting has a good default; most people never open settings.
    A setting exists only when two reasonable people would choose differently.

## What was taken from the inspiration, and what was left

| Source | Taken | Left out, and why |
|---|---|---|
| [fedyaqq34356/hyprdots](https://github.com/fedyaqq34356/hyprdots) | The island that takes the clock's place and grows into music, timers, messages, volume, downloads; one Quickshell process for everything; closed panels are not loaded; the island stops animating under fullscreen; measured performance budget | Wallpaper-generated palettes (contrast is not controllable), goo/liquid seams between shapes (too busy for daily work), desktop widgets, sixty island knobs (settings for their own sake) |
| [denonmaryland/omarchy-dotfiles](https://github.com/denonmaryland/omarchy-dotfiles) | The rail and the screen frame as **one surface**, drawers that grow out of it instead of floating, the search-first menu ("What do you need?") | A left rail (costs horizontal space on a 1080p laptop), the quarter-circle corner (beautiful but slow to operate with a TrackPoint), recessed windows |
| [tacit-os/tacit](https://github.com/tacit-os/tacit) | The notch that says one line when something finishes then goes quiet; search that finds apps, files, settings and sums and hands the rest to the web; **the behaviour rules** (a way out by key and pointer, keyboard only while open, one layer size with an input mask, windows never move, nothing under a passing pointer); text ranked by ink levels checked with APCA; colour by meaning; "docked, not floating" with coves; no generic patterns | Dark only (Lenno uses light during the day), wallpaper palette, its own apps |
| [elifouts/Dotfiles](https://github.com/elifouts/Dotfiles) | Tapping Super opens the launcher; a keybind list inside the shell; the calm, earthy, low-contrast-chrome look; a minimal "zen" state where only the workspaces stay | Pywal, many interchangeable styles and profiles (one well-made style beats five), the bottom-left notifications |
| r/unixporn: "have not seen a gruvbox rice in a bit" | The **warmth**: brown-black grounds, cream ink, muted earthy accents. aptus's Ember palette is in that family, tuned for contrast | Gruvbox's saturated yellows and reds as everyday colours (they are reserved for warnings here) |
| r/unixporn: "niri: a spotlight knockoff" | The single centred search field as the main way into everything | — |

The two Reddit posts could not be opened from this machine (Reddit refuses automated access), so
only their titles informed the design. Screenshots pasted later can refine
[03-visual-language.md](03-visual-language.md) and [surfaces/spotlight.md](surfaces/spotlight.md).

## The signature ideas

1. **The frame.** A 6 px band around the screen, 32 px at the top, in the ground colour. Window
   corners and the frame's inner corners are concentric (10 px window radius + 8 px gap = 18 px).
   It makes the laptop screen feel like a finished object.
2. **The notch is the shell's voice.** At rest: the clock. Then, without ever covering more than it
   must: a toast, a volume level, a timer ring, a meeting countdown, a screenshot thumbnail. Press
   Super and the same shape becomes Spotlight. Click the clock and it becomes Today.
3. **Spotlight reaches everything.** Apps, open windows, files, actions ("wifi off", "focus 50"),
   settings, a calculator, the clipboard, emoji, quick notes, timers, web search, shell commands.
4. **Focus sessions.** One key starts 50 minutes of deep work: notifications are held, the bar goes
   quiet, the notch shows a slowly filling ring, and at the end you get a summary of what waited.
5. **Agenda awareness.** The notch shows "Stand-up in 9 min" with a Join button ten minutes before a
   meeting. Today puts the day's events next to the notifications.
6. **Warm, legible, two-mode palette.** Ember (dark) and Linen (light), with six curated accents, all
   APCA-checked.

## Feature map

| Area | v2 contents | Spec |
|---|---|---|
| Frame & bar | frame, workspaces with app icons, active window, tray, status cluster, privacy indicators | [bar](surfaces/bar.md) |
| Notch | clock, live activities, toasts, OSD, hover expansion, priorities | [notch](surfaces/notch.md) |
| Spotlight | apps, windows, files, actions, settings, calculator, clipboard, emoji, jot, timers, commands, web | [spotlight](surfaces/spotlight.md) |
| Switching | Alt+Tab switcher, overview with live thumbnails and window search, workspace names | [overview](surfaces/overview.md) |
| Deck | toggles, sliders, media, battery and power profile; pages for Wi-Fi, Bluetooth, audio, display, power, VPN | [deck](surfaces/deck.md) |
| Today | date, next event, agenda, month, notifications, jot inbox, focus, weather | [today](surfaces/today.md) |
| Focus | focus sessions, do not disturb, held notifications, statistics | [focus](surfaces/focus.md) |
| Capture | region/window/screen screenshots, recording, colour picker, annotate | [capture](surfaces/capture.md) |
| Session | lock screen, idle, session sheet, graceful logout, polkit prompts | [session](surfaces/session.md) |
| Wallpaper | wallpaper drawing, gallery with live preview, transitions | [wallpaper](surfaces/wallpaper.md) |
| Settings | settings window, search, live apply | [settings](surfaces/settings.md) |
| Helpers | keybind cheatsheet, jot (quick notes) | [keys and jot](surfaces/keys-jot.md) |
| Theming | aptus palette in GTK, Qt/KDE, terminals, editors, browser, mail, prompt, tools | [08-theming](08-theming.md) |
| Isolation | lease, scope, guard, recovery, audit | [02-isolation](02-isolation.md) |
