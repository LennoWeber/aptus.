# Wallpaper and gallery

## 1. Purpose

The wallpaper is the one place where colour and images are allowed. aptus draws it itself (no
hyprpaper, no swww), so it can crossfade, preview live, feed the lock screen and the `wallpaper`
accent, and stay completely separate from Noctalia's wallpaper in Umbriel.

## 2. Drawing

- One `aptus-wallpaper` layer per monitor (`WlrLayer.Background`, no input, exclusive zone −1,
  namespace `aptus-wallpaper`), the full monitor size.
- The image is decoded at the monitor's pixel size (`sourceSize` = logical size × scale), so a 6K
  image costs the same memory as a screen-sized one. `asynchronous: true`; the old image stays until
  the new one is decoded, then M-28 runs.
- Hyprland's own background is turned off (`misc.disable_hyprland_logo`, `force_default_wallpaper
  = 0`) and its background colour is set to `ground`, so the first frames before the shell starts
  are the frame colour, never a flash of Hyprland's default wallpaper or of black.
- Formats: JPEG, PNG, WebP (qt6-qtimageformats), AVIF, JXL, HEIF (kf6-kimageformats, both already
  installed). Animated files show their first frame; video wallpapers are a non-goal.

### Fill modes (`wallpaper.fill`)

| Mode | Behaviour |
|---|---|
| `fill` (default) | cover the monitor, cropped around `wallpaper.focus` (default centre) |
| `fit` | contain, the rest `ground` |
| `center` | native size, centred, the rest `ground` |
| `tile` | repeat at native size |

## 3. State

`~/.local/state/aptus/wallpaper.json`, written atomically:

```json
{
  "v": 1,
  "all": "/home/lenno/Pictures/Wallpapers/forest.jpg",
  "monitors": { "DP-1": "/home/lenno/Pictures/Wallpapers/dunes.jpg" },
  "byMode": { "dark": null, "light": null },
  "favourites": ["…"],
  "rotation": { "order": ["…"], "index": 4, "next": "2026-11-07T15:00:00+01:00" }
}
```

Resolution per monitor: `monitors[name]` → `byMode[current mode]` → `all` → the newest image in
`wallpaper.dir` → plain `ground`. aptus never reads or writes Noctalia's `[wallpaper]` settings;
on the very first start it simply uses the newest image in `wallpaper.dir`.

## 4. Gallery (`Super+W`)

A notch mode (morphs like every notch mode, keyboard exclusive):

```
 ────────────╮                                                                   ╭────────────
             ╰───────────────────────────────────────────────────────────────────╯
             │ Wallpapers   All  Favourites  Dark  Light            ⌕ filter…   ▢ │  header 44: tabs (segmented), field, fill-mode menu
             │ ┌──────┐ ┌──────┐ ╔════════╗ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ │
             │ │      │ │      │ ║        ║ │      │ │      │ │      │ │      │ │  thumbnails 160 × 90 (r 10), gap 12
             │ └──────┘ └──────┘ ╚════════╝ └──────┘ └──────┘ └──────┘ └──────┘ │  selected: scale 1.06, focus ring
             │ forest.jpg · 3840 × 2160 · ♥                  ↵ Set   ⇧↵ This monitor │  footer 28: name, size, keycaps
             ╰────────────────────────────────────────────────────────────────────╯
                                    width min(1240, monitor − 64), height 196
```

- Opens with the current wallpaper selected and centred; the strip scrolls so the selection stays in
  the middle third.
- **Live preview:** resting 250 ms on a thumbnail (keyboard or pointer) shows it on the desktop of
  the active monitor with M-28 (M-29). Moving on starts a new crossfade from wherever the current
  one is.
- `Enter` / click: set for every monitor (`all`), close. `Shift+Enter`: this monitor only.
  `Ctrl+Enter`: for the current mode only (`byMode`).
- `Esc`: close and crossfade back to the wallpaper that was set.
- `F`: favourite on/off (a `favorite` glyph `FILL` 1 in the footer). `R`: a random one (previewed).
  `Ctrl+Delete`: move the file to the trash (risk, Enter twice; `gio trash`, so it can be restored).
  `Ctrl+O`: show in folder. Typing filters by file name (the field takes the text, arrows keep
  moving the selection).
- Tabs `Tab`/`Shift+Tab`: All, Favourites, Dark (images whose mean lightness is below 50 %),
  Light.
- Fill-mode menu (`▢`): the four modes, applied live to the preview.
- Empty folder: the empty state "No images in ~/Pictures/Wallpapers" with **Open folder** and
  **Choose folder…** (a portal file chooser in folder mode).

## 5. Thumbnails and analysis

- Thumbnails are 320 × 180 JPEG (2× for the 160 × 90 cells) in
  `~/.cache/aptus/wall-thumbs/<sha1(path + mtime + size)>.jpg`, generated in QML (`Image` with
  `sourceSize` + `grabToImage().saveToFile()`), four at a time, visible ones first.
- The same pass computes, from a 48 × 27 downscale (`Canvas.getImageData`): mean OKLab lightness,
  and the chroma-weighted circular mean hue. Results go to
  `~/.cache/aptus/wall-thumbs/index.json`. Lightness drives the Dark/Light tabs and the glass rule
  ([03](../03-visual-language.md) §3); the hue drives the `wallpaper` accent
  ([03](../03-visual-language.md) §2.2: the curated accent with the nearest hue; images with mean
  chroma below 0.03 keep the previous accent).
- The folder is watched (`FolderListModel`); new files appear in the strip within a second.
  Thumbnails of deleted files are pruned on the next gallery open.

## 6. Rotation

`wallpaper.rotate` = `off` (default) | `30m` | `1h` | `3h` | `daily` (at 06:00). The order is a
shuffle of the folder (favourites only with `wallpaper.rotateFavourites`), never repeating until
every image was shown, persisted in `rotation`. Rotation changes `all` only; monitors with their own
image keep it. The next change happens at an absolute time, so shell restarts never skip or repeat.
Spotlight "Next wallpaper" advances it by one.

## 7. Elsewhere

- **Lock screen:** each monitor's wallpaper, blurred and dimmed ([session.md](session.md) §1).
- **Overview:** the dimmed area below the cards shows the wallpaper with a 50 % scrim.
- **Accent:** with `appearance.accent = wallpaper`, a change of `all` (or of the active monitor's
  own image) can change the accent; the shell crossfades (M-30) after the wallpaper crossfade ends.
- **Apps:** the wallpaper is never written to any shared place (no `~/.config/background`, no GNOME
  `picture-uri`), so Umbriel's wallpaper is untouched.

## 8. Edge cases

- The file disappears (renamed, unmounted drive): the last decoded image stays on screen for the
  session; on the next start the resolution order falls through, and a toast says "forest.jpg is
  gone — using dunes.jpg".
- A huge image (> 120 MP): decoded at monitor size like any other; the thumbnail pass may take a
  second; nothing blocks.
- A monitor is plugged in: it gets `monitors[name]` if remembered, else `all`, without animation.
- Portrait monitor (after `Super+R` rotation): `fill` recomputes from the rotated size.

## 9. Settings

`wallpaper.dir`, `wallpaper.fill`, `wallpaper.focus`, `wallpaper.rotate`,
`wallpaper.rotateFavourites`, `appearance.accent`. Defaults in [10-settings.md](../10-settings.md).
