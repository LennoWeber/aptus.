# Session: lock, idle, session sheet, logout, polkit

## 1. Lock screen

### Look

```
 ┌────────────────────────────────────────────────────────────────────┐
 │                                                                    │
 │                           14:32                                    │  display 112 / 200, ink.main
 │                    Saturday, 7 November                            │  title, ink.sec
 │                                                                    │
 │                ╭──────────────────────────────╮                    │
 │                │ ●●●●●●▏                    ◉ │                    │  password pill 320 × 44, sunken, r 22
 │                ╰──────────────────────────────╯                    │  placeholder "Password for lenno"
 │                      Caps Lock is on                               │  (only when on; warn)
 │                                                                    │
 │  3 notifications              ▣ Track — Artist  ◁ ⏸ ▷        ▮ 64 %│  bottom row: counts only, media, status
 └────────────────────────────────────────────────────────────────────┘
   background: the wallpaper, blurred 48 px, dimmed 45 % (Ember) / 28 % (Linen scrim)
```

- Clock at 38 % of the monitor height, the pill at 62 %. Other monitors show only the clock and date.
- Notification **counts only** (no titles: privacy, `lock.showNotificationCount`); media controls
  work without unlocking; battery and network status at the bottom right.
- The keyboard always goes to the pill; typing starts with the first key (no click needed).

### Lock and unlock (M-25)

| Phase | t (ms) | What happens |
|---|---|---|
| Lock | 0 | every output is captured (frozen desktop); the session lock is requested |
| | 0 → 420 | on the lock surface: the frozen desktop blurs 0 → 48 px and dims; it crossfades into the blurred wallpaper by 420 ms, so at rest **no window content** is behind the lock, even blurred |
| | 160 → 460 | clock rises 12 px and fades in; pill at 300 |
| Wrong password | 0 → 320 | pill shakes ±8 px three times; "Wrong password" (`crit`) fades in under it; field cleared, keeps focus |
| Unlock | 0 → 160 | pill's glyph turns into a check; clock and pill fade out; only the blurred, dimmed wallpaper remains |
| | 160 | the session lock is released, and in the same frame the **veil** (an input-less `aptus-veil` overlay layer per monitor, already showing the identical blurred, dimmed wallpaper) takes over, so nothing visibly changes |
| | 160 → 440 | the veil's opacity 1 → 0 (`exit` curve) while its blur drops 48 → 0: the live desktop appears from behind it |

The lock surface cannot fade to reveal the desktop (the compositor shows nothing but lock surfaces
while locked), which is why the veil exists. A failed handover (the veil not ready within 50 ms)
simply skips the fade.

### Authentication
- `PamContext` with the PAM service **`hyprlock`** (`/etc/pam.d/hyprlock`, installed by Fedora's
  hyprlock package and meant for screen lockers), so aptus needs no system file.
- PAM messages are shown under the pill (`ink.sec`; errors `crit`), including faillock's
  "Account locked for 10 s" after repeated failures.
- Fingerprint (`lock.fingerprint`, default off, probe P-22): when enabled and a finger is enrolled
  (`fprintd-list`), a `fingerprint` glyph appears in the pill and `fprintd-verify` runs in parallel;
  its success unlocks; password typing keeps working.

### Robustness
- The shell writes `~/.local/state/aptus/locked` when it locks and removes it when it unlocks.
  Hyprland is configured with `misc.allow_session_lock_restore = true`.
- If the shell crashes while locked, Hyprland keeps the session locked (the protocol guarantees it);
  the supervisor restarts the shell within 1 s, which sees the marker and locks again at once.
- If the shell fails to start three times within 10 s, the supervisor starts
  `hyprlock -c ~/.local/state/aptus/hyprlock.conf` (styled by aptus, isolation row 36; Lenno's own
  `hyprlock.conf` stays untouched) to take over the lock.
- Recording stops and saves before the lock surface appears.

## 2. Idle

Quickshell `IdleMonitor`s (ext-idle-notify, `respectInhibitors: true`):

| After (no input) | Action | Undo on input |
|---|---|---|
| `idle.dimAfter` 270 s | dim eDP-1 brightness to 30 % of the current value over 2 s; external monitors get a 50 % black overlay on the shell layer | restore over 300 ms |
| `idle.lockAfter` 300 s | lock | — |
| `idle.screenOffAfter` 600 s | `dpms off` (all monitors) | `dpms on` |
| locked and idle 60 s (`idle.lockedScreenOffAfter`) | `dpms off` | `dpms on` |

Inhibited while: *Keep awake* is on (Deck); an app holds a Wayland idle inhibitor (video players,
browsers playing fullscreen video, Hyprland rule `idle_inhibit fullscreen` for every window); a focus
session never inhibits. aptus never suspends on idle (`power.allowSuspend` default false, D-01).

## 3. Lid

`power.lidAction`:

| Value | Behaviour |
|---|---|
| `lock` (default) | aptus holds a logind `handle-lid-switch` *block* inhibitor for the life of the session (a transient unit bound to the guard, so it ends with Hyprland and never affects Umbriel). Lid closed: lock, eDP-1 `dpms off`. With an external monitor connected, eDP-1 is disabled instead (`power.lidDocked: disable-internal`) and re-enabled when the lid opens. |
| `suspend` | no lid inhibitor; logind's own policy applies. aptus holds a `sleep` *delay* inhibitor and locks on logind's `PrepareForSleep` before releasing it, so the machine always wakes locked. |

## 4. Session sheet (`Super+X`)

```
 ────╮                                                        ╭────
     ╰────────────────────────────────────────────────────────╯
     │   🔒          ⇥            ⟳             ⏻              │   four tiles 120 × 96 (raised, r 12)
     │   Lock       Log out      Restart       Shut down        │
     │    L            O            R              S           │   keycaps
     │   Up 3 h 12 min · 7 windows open                         │   ink.meta
     ╰──────────────────────────────────────────────────────────╯   560 × 176, scrim behind (M-27)
```

- Keys: `L`, `O`, `R`, `S` (and `U` for Suspend when `power.allowSuspend`), or `← →` + `Enter`.
- **Lock** acts at once.
- **Log out, Restart, Shut down** (risk): the first activation starts a 3 s countdown ring on that
  tile, its label becomes "Restarting in 3…", and a line says "Enter to restart now · Esc to cancel".
  The same key or `Enter` acts at once; `Esc` or any other key cancels.
- The Deck's power button morphs into this sheet.

## 5. Graceful end of session

Used by Log out, Restart, Shut down (from the sheet, Spotlight, or `Super+M`, which skips the
countdown because Lenno bound it deliberately):

1. The notch shows "Closing 7 windows…".
2. aptus asks every window to close (`closewindow`), topmost first, and waits up to
   `session.closeTimeout` (6 s) for them to unmap.
3. If windows remain (typically a "save changes?" dialog): stop. The notch card says "Zen and 1 other
   window are still open" with **Show** (focus the first), **Close anyway** (risk: `kill` their
   processes, continue), **Cancel**.
4. When all are closed: the guard is told to release the lease now (it would also do it at exit),
   transient units stop, then: log out → Hyprland `exit`; restart → `systemctl reboot`; shut down →
   `systemctl poweroff`.

## 6. Polkit prompt

aptus is the session's polkit agent (`PolkitAgent`), only in Hyprland.

```
 ────╮                                                        ╭────
     ╰────────────────────────────────────────────────────────╯
     │ 🛡  Authentication is required to install software      │   glyph (requesting app's icon if known)
     │    dnf · org.fedoraproject.dnf…           Details ›    │   meta; Details expands action id, program
     │ ╭───────────────────────────────────────────────────╮  │
     │ │ Password for lenno                               ◉ │  │   field
     │ ╰───────────────────────────────────────────────────╯  │
     │                            [ Cancel ]  [ Authenticate ]│
     ╰─────────────────────────────────────────────────────────╯   480 wide, scrim behind (M-27)
```

- Appears on the active monitor, over everything except the lock, with exclusive keyboard.
- Wrong password: shake + PAM message; the flow stays open for the next attempt.
- Several identities (other admin users): a segmented control above the field.
- Cancel / Esc: `cancelAuthenticationRequest`.
- If another polkit agent is already registered (for example one started by an XDG autostart entry),
  aptus cannot register: a toast says so, and `aptus doctor` names the other agent.

## 7. Settings

`lock.showNotificationCount`, `lock.fingerprint`, `lock.showMedia`, `idle.dimAfter`,
`idle.lockAfter`, `idle.screenOffAfter`, `idle.lockedScreenOffAfter`, `power.allowSuspend`,
`power.lidAction`, `power.lidDocked`, `session.closeTimeout`. Defaults in
[10-settings.md](../10-settings.md).
