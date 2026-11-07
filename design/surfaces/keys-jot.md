# Keys cheatsheet and Jot

Two small notch modes that keep you in flow: one answers "what was the key for…?", the other
catches a thought before it is gone.

## 1. Keys (`Super+K`)

### Look

```
 ──────────╮                                                                          ╭──────────
           ╰──────────────────────────────────────────────────────────────────────────╯
           │ Keys                                                 Type to search  ⌕   │  header 44
           │                                                                          │
           │ Shell                     Windows                  Workspaces            │  group titles (title)
           │ Spotlight      Super      Close        Super Q     Go to 1–10  Super 1…0  │  rows 28: description
           │ Overview   Super Tab      Float        Super V     Move window  ⇧ Super 1…0│  (body) + keycaps
           │ Deck         Super C      Fullscreen   Super F     Next      Super Ctrl → │
           │ Today        Super N      Focus     Super ←↑→↓     …                      │
           │ …                         …                                               │
           │ Capture                   Media and hardware       Apps                  │
           │ …                         …                        …                     │
           │                                       Edit in Settings › Keys   ?  in any surface │ footer 28
           ╰──────────────────────────────────────────────────────────────────────────╯
                     width min(1120, monitor − 64), three columns, height = content (max 70 %)
```

- Groups and order: Shell, Windows, Workspaces, Capture, Media and hardware, Apps. Columns are
  balanced by row count (greedy, groups never split).
- A row: description in `body` `ink.sec`, keycaps right-aligned (`Super` written out, `Shift` as `⇧`, arrows as glyphs;
  ranges collapsed: `1…0`).
- Rows for binds Lenno changed in Settings carry a 6 px accent dot (they differ from the default).

### Behaviour

- Opens on the active monitor; keyboard exclusive. `Super+K` again, `Esc`, or a click outside closes.
- **Typing** morphs the sheet into Spotlight's keys scope (`?`) with the typed text, where `Enter`
  performs the selected bind ([spotlight.md](spotlight.md) §5). So the sheet is for looking, the
  scope for doing.
- `↑ ↓ ← →` move a selection through rows (column-major); `Enter` performs the selected bind and
  closes; `Ctrl+C` copies the chord as text.
- **Holding** `Super` for 1 s with no other key (`spotlight.superHoldKeys`, default on) shows the
  same sheet while Super is held and hides it on release, without taking the keyboard, so a chord
  can be pressed while reading. A tap still opens Spotlight; a release after the peek was shown
  does not (both come from Super binds, probe P-02).

### Data

- Global binds: `hyprctl binds -j` (re-read on `config.reloaded`). Every aptus bind carries a
  description `"aptus:<id> | <Group> | <Description>"` ([09-hyprland.md](../09-hyprland.md) §7);
  the id lets Settings › Keys edit it. Lenno's own binds (no description) are named from
  `shell/config/known-binds.json` (dispatcher and argument patterns → group and description, e.g.
  `exec_cmd ghostty|kitty` → Apps · Terminal); anything unmatched appears under **Other** with a
  description derived from the dispatcher ("exec ~/.local/bin/toggle-laptop-rotation.sh" → "Run
  toggle-laptop-rotation").
- Mouse binds and binds whose description ends in `| hidden` are left out.

### Surface keys (`?`)

Inside any open surface, `?` (when no text field has content) shows that surface's own keys as an
overlay inside it: a `raised` card (radius 12) over the bottom of the surface, two columns of
key + meaning, from the surface's `keys` list in QML. `?` or `Esc` hides it. The overlay never
covers the field.

## 2. Jot (`Super+Shift+N`)

### Look

```
 ────────────────╮                                       ╭────────────────
                 ╰───────────────────────────────────────╯
                 │ ✎  Jot something…                     │   field 40 (sunken, r 12)
                 │    ☐ Todo  ·  inbox.md   ↵ Save  Esc  │   footer 24: todo chip, file, keycaps
                 ╰───────────────────────────────────────╯   width 560, height 96
```

### Behaviour

| Input | Result |
|---|---|
| Type, `Enter` | append the text as a note; the notch shows the event "Jotted" with a `check` glyph (1.2 s) |
| `Tab` or typing `[] ` / `- [ ] ` at the start | toggle **Todo** (the chip fills); `Enter` appends a todo |
| `Shift+Enter` | new line in the same jot (the field grows to 4 lines, then scrolls) |
| `Ctrl+Enter` | append and open Today scrolled to the inbox |
| `Ctrl+Shift+V` with an image on the clipboard | attach it: saved as `attachments/2026-11-07-143205.png` next to the inbox file, and `![](attachments/…)` is added to the jot |
| `↑` in an empty field | recall the last jot for editing (it replaces that line on Enter) |
| `Esc` | close; a non-empty draft is kept and comes back on the next open (`~/.local/state/aptus/jot-draft.txt`) |

Spotlight's `+ text` does the same as Jot with `Enter`.

### File format

`jot.file` (default `~/Notes/inbox.md`), plain Markdown that stays readable in any editor:

```markdown
# Inbox

## Sat 7 Nov 2026
- call the bank
- [ ] buy milk
- [x] send the invoice
- idea: the notch could show the build status
  of the current repo (second line of a multi-line jot, indented)
```

- Appends go to the end under today's date heading (created when missing). The file and its folder
  are created when missing.
- Appends are written with `O_APPEND` in one `write`, so an editor holding the file open never loses
  them. Edits (toggle, delete, recall) re-read the file, find the line by its exact text under its
  heading, and rewrite atomically; if the line is no longer there, nothing changes and a toast says
  "The inbox changed — open it to edit".
- Today shows the newest 8 entries regardless of headings ([today.md](today.md) §8).

### Motion

The notch morphs into the Jot sheet (M-09 geometry at 560 × 96). On `Enter`: the text slides up
8 px and fades (`exit` 140) while the sheet collapses into the "Jotted" event (M-37); with
`Ctrl+Enter` it morphs into Today instead.

## 3. Settings

`spotlight.superHoldKeys`, `jot.file`, `jot.attachmentsDir` (default `attachments` beside the file),
`jot.dateHeadings` (true). Defaults in [10-settings.md](../10-settings.md).
