# Capture: screenshots, recording, colour picker

## 1. Purpose

Take exactly what you meant, in one gesture, and have it ready where you need it (clipboard, file,
annotation) without a dialog.

## 2. Entry points

| Key | Mode |
|---|---|
| `Print`, `Super+Shift+S` | region (hover a window to take the window, drag for a region) |
| `Shift+Print` | the active monitor, immediately |
| `Super+Shift+R` | record: choose like region mode; again to stop |
| `Super+Shift+C` | colour picker |
| Deck footer, Spotlight actions | any of the above |

## 3. Selection overlay

On trigger, aptus captures every monitor once (`ScreencopyView`, not live) and shows that frozen image
on the monitor's `aptus-shell` layer above every other surface (exclusive keyboard; one layer, so the
thumbnail can fly from the selection into the notch, M-23, [07](../07-architecture.md) §4).
What you see is exactly what will be saved: the moment you pressed the key.

```
 ┌───────────────────────────────────────────────────────────────┐
 │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  outside the selection: scrim 40 %
 │░░░░░░░░░┌───────────────────────────┐░░░░░░░░░░░░░░░░░░░░░░░░░│
 │░░░░░░░░░│                           │░░░░░░░░ ◯ loupe 120 px  ░│  8× zoom of the pixels under the
 │░░░░░░░░░│     (frozen screen)       │░░░░░░░░   #9ACFAE 812,404│  pointer, centre pixel outlined,
 │░░░░░░░░░│                           │░░░░░░░░░░░░░░░░░░░░░░░░░│  hex + coordinates (micro)
 │░░░░░░░░░└───────────────────────────┘░░░░░░░░░░░░░░░░░░░░░░░░░│
 │░░░░░░░░░░░░░░░░░░ 1280 × 720 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  size chip under the selection
 └───────────────────────────────────────────────────────────────┘
```

| Input | Result |
|---|---|
| Move the pointer over a window | that window's rectangle is highlighted (2 px accent ring, inside dimmed less); the loupe follows the pointer |
| Click (no drag) on a window | capture that window (its own buffer, without overlapping windows) |
| Click on the desktop / wallpaper | capture that monitor |
| Drag | draw a region (6 px threshold); the region shows 8 handles after release |
| Drag a handle / inside the region | resize / move it |
| Arrow keys | move the region 1 px (`Shift`: 10 px); with `Alt`: resize from the bottom-right |
| `Enter` | capture the region (or, with none, the monitor under the pointer) |
| `R` | reuse the previous region |
| `W` | window mode only (ignore drags) |
| `Esc`, right click | cancel |

The loupe stays inside the screen (16 px margin), flipping to the other side of the pointer near
edges. Selections cannot cross monitors; a drag reaching another monitor clamps at the edge.

## 4. After a screenshot

1. The image is cut from the frozen frame (region/monitor) or taken from the window's buffer
   (window), at native resolution.
2. It is saved as PNG to `capture.dir` (`~/Pictures/Screenshots/Screenshot 2026-11-07 14-32-05.png`)
   and, with `capture.copy` (default on), copied as `image/png` (`wl-copy`).
3. The overlay disappears and the thumbnail flies from the selection into the notch (M-23), which
   grows into the **capture card** (420 × 120): thumbnail 176 × 99 (radius 8), "Copied · Saved" in
   `ink.meta`, quiet buttons **Annotate** (opens `satty` with the file; saving in satty overwrites),
   **Show in folder**, **Delete** (risk; the card then offers *Undo* for 5 s).
4. The card stays 6 s (paused while hovered). Clicking the thumbnail opens the image in the default
   viewer.

## 5. Recording

- `Super+Shift+R` opens the same overlay with a `crit` "Record" chip at the top centre. Region, window
  (its rectangle at the time of the click) or monitor, then `Enter`/click starts at once. With
  `capture.countdown` (default off), the notch counts 3-2-1 first.
- Encoder: `wf-recorder` with VAAPI H.264 on the Intel GPU (`-c h264_vaapi -d /dev/dri/renderD128`,
  `renderD128` is the i915 node, `renderD129` the NVIDIA one; probe P-15; fallback `libopenh264`,
  because Fedora's `ffmpeg-free` has no `libx264`), MP4 into `capture.recordDir`
  (`~/Videos/Recordings`), audio per `capture.recordAudio`: `none` (default) | `system` (monitor of
  the default sink) | `mic` | `both`.
- While recording: notch right slot shows the breathing `crit` dot and elapsed time (M-24); the
  status cluster shows the privacy indicator; a 2 px `crit` frame is drawn **outside** the recorded
  region on an input-less overlay layer (so it is never in the video); none for full-monitor
  recordings.
- Stop: `Super+Shift+R`, the recording card's Stop, Spotlight "Stop recording", or locking the
  screen (recording must never capture the lock screen; it stops and saves first).
- After stopping: a capture card with the first frame (`ffmpeg -frames:v 1` if available, else a
  `movie` glyph), duration and size, buttons Open, Show in folder, Copy path, Delete (risk + undo).

## 6. Colour picker

- The overlay without scrim and without selection: only the loupe, larger (160 px, 10×).
- Click or `Enter` picks the centre pixel; `Esc` cancels; arrows move the pointer 1 px for precise
  picking.
- The value is copied in `capture.colourFormat` (`hex` default | `rgb` | `hsl` | `oklch`), and the
  notch shows a **colour card**: swatch 48, the value in each format as rows (`Enter`/click copies a
  row), and the last 8 picked colours as small swatches (click to copy again). History in
  `~/.local/state/aptus/colours.json`.

## 7. Edge cases

- Capture while a menu, Spotlight or another interactive notch mode, the Deck or Overview is open:
  they close first (one frame), then the freeze happens, so they are not in the image. With
  `capture.includeShell` on they stay open and are part of the image. Passive notch content (toasts,
  OSD, cards) stays either way. Capture never opens beside the polkit prompt: it queues behind it,
  and a polkit request during the selection cancels the selection.
- A monitor connected during the selection cancels it (as `Esc`); one disconnected simply drops out.
- Multi-monitor with different scales: each monitor's frozen frame at its own scale; regions are cut
  in that monitor's native pixels.
- A protected surface (DRM video): it is whatever the compositor gives (black); no error.
- Disk full: the card says "Could not save — disk full" with **Copy only** (the image is still on the
  clipboard).
- `wf-recorder` exits unexpectedly: the recording state ends, a toast with the last line of its
  error output and the partial file if it exists.

## 8. Data

`Capture` service: frozen frames via `ScreencopyView` (`captureSource` = screen or toplevel),
`grabToImage` for cropping and saving, `wl-copy`, `satty`, `wf-recorder` (as a transient unit bound
to the guard so a crashing shell cannot leave it running unattended; the shell re-attaches to it on
restart by unit name).

## 9. Settings

`capture.dir`, `capture.recordDir`, `capture.copy`, `capture.countdown`, `capture.recordAudio`,
`capture.colourFormat`, `capture.includeShell`, `capture.fileName` (pattern, default
`Screenshot %Y-%m-%d %H-%M-%S`). Defaults in [10-settings.md](../10-settings.md).
