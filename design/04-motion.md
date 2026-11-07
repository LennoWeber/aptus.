# 04 · Motion

## 1. Principles

1. **Motion says where things come from.** A drawer grows out of the frame where it lives and goes
   back there. A screenshot thumbnail flies from the captured region into the notch. Nothing slides
   in from an arbitrary side.
2. **Never wait for an animation.** Input is accepted from the first frame. Typing into Spotlight
   works while it is still growing; Esc during an opening reverses it from where it is.
3. **Fast in, gentle out, short always.** Entering motion decelerates; leaving motion accelerates and
   is 30 % shorter. Nothing in the shell takes longer than 420 ms except the ambient crossfades
   (wallpaper, theme), which never block anything.
4. **Interruptible.** Every geometric animation can be retargeted mid-flight from its current value
   and velocity. Springs are used wherever a target can change while moving.
5. **Quiet at rest.** When nothing changes, nothing moves. The only perpetual animation is the
   recording dot, because it is a privacy signal.
6. **Text does not stretch.** Text only fades and translates (never scales), except the clock's
   digit roll.

## 2. Tokens

### 2.1 Durations (ms)

| Token | Enter | Exit | Use |
|---|---|---|---|
| `press` | 60 | 60 | pressed wash and scale |
| `hover` | 120 | 120 | hover washes, tooltip fade |
| `fade` | 160 | 110 | content crossfades, text swaps |
| `small` | 200 | 140 | toggles, chips, icon `FILL`, badges |
| `surface` | 280 | 200 | drawer open/close (Deck, menus) |
| `page` | 300 | 220 | page push/pop inside a drawer |
| `morph` | 380 (spring settle) | 300 | notch shape changes, Spotlight, Today |
| `intro` | 420 | — | the session intro |
| `ambient` | 400 / 600 | same | theme crossfade (400), wallpaper crossfade (600) |

### 2.2 Curves (cubic Bézier)

| Token | Points | Use |
|---|---|---|
| `standard` | (0.2, 0, 0, 1) | things moving within the screen, colour changes |
| `enter` | (0.05, 0.7, 0.1, 1) | anything appearing or growing |
| `exit` | (0.3, 0, 0.8, 0.15) | anything leaving or shrinking |
| `linear` | (0, 0, 1, 1) | progress that tracks time (focus ring, timers, recording time) |

### 2.3 Springs

Springs drive geometry that can be retargeted: the notch's width and height, the workspace capsule,
the selection highlight, slider thumbs, level bars. They are specified by what you see; the QML
parameters are starting values that the implementation calibrates (probe P-21: record at 60 fps,
measure settle time and overshoot, adjust).

| Token | Damping ratio ζ | Settle (to 1 %) | Overshoot | QML `SpringAnimation` start values |
|---|---|---|---|---|
| `spring.notch` | 0.78 | 380 ms | 2–3 % | `spring: 4.0; damping: 0.30; mass: 1.0; epsilon: 0.25` |
| `spring.snappy` | 0.90 | 240 ms | < 1 % | `spring: 5.0; damping: 0.40; mass: 1.0; epsilon: 0.25` |
| `spring.gentle` | 1.00 | 320 ms | 0 % | `spring: 3.0; damping: 0.45; mass: 1.0; epsilon: 0.25` |

When a spring is not in flight and the change is not retargetable (a drawer that only opens and
closes), the Bézier tokens are used instead; they are cheaper and exactly timed.

## 3. Choreography rules

1. **Container first, content second.** A surface's geometry starts at t = 0. Its content fades in
   from t = 60 ms over `fade`, rising 8 px (`enter`). On exit, content fades out first (0–100 ms)
   while the geometry collapses from t = 40 ms.
2. **Stagger lists, but briefly.** The first six rows enter 18 ms apart (total ≤ 110 ms). Rows
   beyond the sixth appear with the sixth. Rows that are already visible never re-stagger when the
   query changes; only new rows enter.
3. **Shared elements move, they do not fade.** When something exists before and after a change (the
   clock when a compact activity appears beside it, the app icon of a toast that becomes a Today
   row), it travels to its new place with `standard`.
4. **Two properties for text at most:** opacity and translate.
5. **Numbers.** Values that change rarely (clock minutes, battery %) roll: the old digit moves up 6 px
   and fades, the new one comes from 6 px below (`fade`, `standard`), per changed digit only. Values
   that change fast (volume, brightness, timers) change instantly.
6. **Icons.** On/off changes animate the `FILL` axis 0↔1 and `wght` 400↔500 over `small`. Swaps
   between different glyphs crossfade with a 0.8→1 scale over `small`.
7. **Exit is the reverse, shorter.** Every exit mirrors its entrance with `exit` timings.
8. **One hero at a time.** If two surfaces change at once (Deck opening while Today closes), the one
   the user asked for gets the full timeline; the other uses its exit timeline without content
   choreography.

## 4. Catalogue

Every animation in the shell has an ID. Surface documents refer to these IDs and give the full
frame-by-frame timelines where needed.

| ID | Trigger | What moves | Timing |
|---|---|---|---|
| M-01 | session start (not shell restarts) | frame thickens 0 → 6 px from the screen edge; bar slides 0 → 32 px down; workspace pills stagger in 30 ms apart; clock fades in last | `intro` 420, `enter` |
| M-02 | workspace change | the accent capsule slides to the new pill; its leading edge leads (`enter`, 180 ms), the trailing edge follows 40 ms later, so it stretches and settles like a drop | 220 total, `spring.snappy` for width |
| M-03 | active window changes | title text: old fades up 4 px, new rises 4 px; app icon crossfades with scale 0.8 → 1 | `fade` |
| M-04 | status icon appears or leaves (mic in use, Bluetooth connected) | width opens 0 → w (`standard`, `small`), then the glyph fades in; reverse to leave | `small` |
| M-05 | compact live activity appears in the notch | the clock slides aside (shared element); the activity's slot opens and its content fades in | `spring.notch` |
| M-06 | toast | bulge grows from the bar (width and height `spring.notch`, coves 0 → 14 in the first 120 ms); app icon scales 0.6 → 1 (`small`); title then body rise 6 px and fade in, 40 ms apart; collapse reverses after the timeout | 380 / 300 |
| M-07 | volume, brightness, mic, keyboard light, caps lock, layout | bulge to 300 × 44; level bar follows each new value with `spring.snappy`; collapses 1 200 ms after the last change | `spring.notch` |
| M-08 | pointer rests 300 ms on a compact activity | bulge grows into that activity's card | `spring.notch` |
| M-09 | Spotlight opens | the notch becomes the search field (timeline in [surfaces/spotlight.md](surfaces/spotlight.md) §8) | 380 |
| M-10 | Spotlight results change | results area height `spring.gentle`; new rows stagger (rule 2); removed rows fade 110 ms without collapsing until the height animation runs | 240–320 |
| M-11 | Spotlight preview pane appears | width 640 → 920 `spring.gentle`, pane content fades in after 100 ms | 320 |
| M-12 | Spotlight scope chip (prefix typed or scope hotkey) | chip slides in from the left inside the field, the query text shifts right with it | `small`, `standard` |
| M-13 | switcher | strip grows from the notch (`spring.notch`); selection highlight moves with `spring.snappy`; quick Alt+Tab tap shows no UI at all | 380 / 240 |
| M-14 | overview | the bar's lower edge drops to 330 px, workspace pills morph into the workspace cards (shared elements: each pill expands into its card), thumbnails fade in 80 ms later | 380 `spring.notch` / 260 out |
| M-15 | dragging a window in the overview | the thumbnail lifts (scale 1.04, shadow), follows the pointer 1:1; target workspace card shows `accentWash`; drop: thumbnail flies into its new slot (`standard` 220) | — |
| M-16 | Deck opens | grows down from the bar at the top-right corner: height 0 → H (`enter` 280), coves grow, content rises 12 px and fades in from 60 ms | 280 / 200 |
| M-17 | Deck page push / pop | new page slides in from the right 24 px + fade, old page slides 24 px left + fades, Deck height animates to the new page's height (`spring.gentle`) | `page` 300 / 220 |
| M-18 | toggle tile on/off | fill crossfades to `accentWash`, glyph `FILL` 0 → 1, state line text swaps (rule 5 style roll) | `small` |
| M-19 | slider | thumb follows the pointer 1:1 while dragging; on click/scroll/keys the thumb moves with `spring.snappy` | 240 |
| M-20 | Today opens | the notch bulge grows to 760 × H (`spring.notch`); the clock travels down into Today's heading position and grows from 13 to 22 px by crossfading two text items at the travelling position (text never scales); columns fade in 60 / 100 ms | 380 / 300 |
| M-21 | notification dismissed | row slides 24 px right and fades (`exit` 140), then the list closes the gap (`standard` 200) | 340 |
| M-22 | focus session | start: ring draws from 0 to its first value (`enter` 400), bar quiet mode (M-31b); during: ring advances `linear` once per second; end: ring completes, then becomes a check mark (`small`) | — |
| M-23 | capture | freeze: the frozen frame appears with no motion, outside of the selection dims to 40 % over 160 ms; after the capture, the thumbnail flies from the selection rectangle to the notch while shrinking (`standard` 420), the notch bulge grows to receive it (M-06 geometry) | 420 |
| M-24 | recording | 8 px crit dot in the notch, opacity 1 → 0.45 → 1 on a 2 400 ms sine; the only perpetual animation | perpetual |
| M-25 | lock / unlock | lock: blur 0 → 48 px and dim 0 → 45 % on a frozen image of the screen (`enter` 420); clock rises 12 px and fades in from 160 ms; field at 300 ms. Wrong password: field shakes ±8 px, 3 oscillations, 320 ms, then `crit` text fades in. Unlock: field glyph becomes a check (`small`) and the content fades; the lock is released and in the same frame an input-less overlay layer (the *veil*) shows the identical blurred, dimmed wallpaper; the veil then fades and unblurs over 280 ms, revealing the live desktop | 420 / 440 |
| M-26 | session sheet | grows from the notch; a chosen action's button draws a 3 s countdown ring (`linear`) | 380 |
| M-27 | polkit prompt, session sheet | scrim fades 0 → 100 % over 200 ms behind the bulge | 200 |
| M-28 | wallpaper change | new image crossfades over the old one while scaling 1.02 → 1.00 (`ambient` 600, `standard`) | 600 |
| M-29 | gallery selection | thumbnail scales to 1.06 with `spring.snappy`; desktop previews the image after 250 ms of rest (M-28) | — |
| M-30 | light/dark or accent change | every colour token animates to its new value (`ambient` 400, `standard`); app targets re-render in the background | 400 |
| M-31 | a window goes fullscreen | frame edges and bar slide out (bar up 32 px, edges outward 6 px) and fade (`exit` 180); back with `enter` 240 | 180 / 240 |
| M-31b | focus session quiet mode | tray, window title and non-critical status fade and collapse (`small`), the bar keeps workspaces, notch and battery | 200 |
| M-32 | tooltip | fade + 4 px rise, 600 ms delay | `hover` |
| M-33 | menu | scale 0.96 → 1 from the anchor point + fade (`enter` 160); exit fade 110 | 160 / 110 |
| M-34 | clock minute | digit roll (rule 5) on changed digits only | `fade` |
| M-35 | unread dot beside the clock | scale 0 → 1 (`spring.snappy`) | 240 |
| M-36 | battery critical, urgent workspace | one nudge: scale 1 → 1.06 → 1 (`standard` 300), repeated at most every 5 minutes; no blinking | 300 |
| M-37 | a jot is saved | the text slides up 8 px and fades (`exit` 140) while the sheet collapses into the "Jotted" event (`spring.notch`) | 380 |
| M-38 | Keys peek (Super held 1 s) | the Keys sheet grows from the notch without content stagger; on release it collapses (`exit` 200) | 280 / 200 |

## 5. Compositor animations (Hyprland)

The shell animates its own layer content; Hyprland must not animate aptus's layers (`no_anim` layer
rules) or it would scale and fade the fixed-size layer windows on top of the shell's own motion.
Window and workspace motion is Hyprland's and uses the same curves. Speeds are in Hyprland units
(1 = 100 ms). The Lua is in [09-hyprland.md](09-hyprland.md) §6.

| Leaf | Speed | Curve | Style | Why |
|---|---|---|---|---|
| `windowsIn` | 2.8 | `aptus_enter` | `popin 92%` | windows open from their own centre, briefly |
| `windowsOut` | 1.6 | `aptus_exit` | `popin 95%` | leave faster than they came |
| `windowsMove` | 2.6 | spring `aptus_move` | — | tiling rearrangement must settle without a bounce |
| `fadeIn` / `fadeOut` | 2.0 / 1.4 | `aptus_standard` | — | |
| `border` | 2.4 | `aptus_standard` | — | focus colour change |
| `workspaces` | 2.6 | `aptus_enter` | `slidefade 12%` | spatial, but short |
| `specialWorkspace` | 2.8 | `aptus_enter` | `slidefadevert 14%` | the scratch terminal drops from the bar |
| `layers` (others) | 2.0 | `aptus_enter` | `fade` | third-party layers fade only |
| `zoomFactor` | 3.0 | `aptus_standard` | — | |

## 6. Theme crossfade (M-30)

All colour tokens in the `Tokens` singleton are animated together: `Tokens` keeps the old and the
new palette and blends every role by one shared progress (a single `NumberAnimation`), so every
bound colour transitions in one 400 ms pass. (`Behavior` cannot be used here: inside a lazily
created singleton it crashes Quickshell 0.3.2, found in S1.) Changes that are not colours (icon theme,
`GRAD` axis) switch at the midpoint (200 ms), hidden by the crossfade. Apps are re-rendered after
the shell has finished its own fade, so the CPU work never stutters the crossfade.

## 7. Reduced motion

`motion.reduce` = `auto` | `on` | `off`. `auto` follows `org.gnome.desktop.interface
enable-animations`, which aptus only reads (it is not a leased key). With reduced motion:

| Normal | Reduced |
|---|---|
| geometry springs and slides | jump to the end state, contents crossfade over 120 ms |
| staggers, digit rolls, shared-element travel | none |
| thumbnail flight (M-23) | the thumbnail fades in inside the notch |
| lock blur ramp | blur at full value immediately, dim fades 120 ms |
| recording dot breathing | steady dot |
| Hyprland window animations | `windowsIn`/`Out` become `fade` at speed 1.2; workspaces `fade` |

## 8. Performance rules

- **Layer windows keep one size.** Each aptus layer surface is created at its final size; animations
  move and clip items inside it and update the input `mask`, never resize the surface.
- Under a fullscreen window on a monitor, all of that monitor's shell animations stop and
  `ScreencopyView`s are released.
- Closed surfaces are not loaded (`Loader { active: false }` after their exit animation).
- At rest, the only timers are: the clock (aligned to the next minute boundary), the focus ring (1 Hz
  while a session runs) and the recording timer (1 Hz while recording).
- Target: 60 fps on eDP-1 with Hyprland's frame time under 8 ms during any shell animation, on the
  Intel UHD 630. Verified per surface in the acceptance tests ([11-roadmap.md](11-roadmap.md)).
- Shadows (MultiEffect) only on open drawers; blur only in glass mode, only behind drawn pixels.
