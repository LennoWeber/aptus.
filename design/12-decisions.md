# 12 · Decisions

## 1. Settled

| ID | Decision | Why | Alternatives rejected |
|---|---|---|---|
| D-04 | **No dock.** Pinned apps live in Spotlight's empty state and in keybinds. | A dock costs a screen edge and duplicates the launcher; the frame stays calm. | an auto-hiding dock (hover-to-reveal breaks "nothing opens under a passing pointer") |
| D-06 | **Curated palettes** (Ember, Linen) and six accents, not wallpaper-generated palettes. | Contrast is measured once and holds everywhere; `wallpaper` only *chooses* among the six. | matugen-style generation (Noctalia's way; unpredictable contrast) |
| D-07 | **Swap the paint, not the wiring.** Isolation leases Noctalia's generated artifacts; it never edits the configs that include them. | Umbriel's configs stay byte-identical; release is a content restore, not a config merge. | a second `HOME`/`XDG_CONFIG_HOME` (breaks app data sharing), `DCONF_PROFILE` (splits app preferences), editing includes |
| D-08 | **One full-monitor Overlay layer** per monitor for the frame and every drawer. | Drawers are one painted shape with the frame; surfaces never resize their layer; works above fullscreen. | one layer per surface (resizing, seams, focus quirks); P-11 keeps it as the fallback |
| D-09 | **aptus draws its own wallpaper.** | Crossfades, live preview, lock-screen reuse, and complete separation from Noctalia's wallpaper. | hyprpaper/swww (another daemon, no shared pixels with the lock) |
| D-10 | **Python for session tools**, QML for the shell, Lua only for Hyprland. | System Python is there in both sessions, has `pidfd_open`, `fcntl.flock`, `zoneinfo`; no build step. | Rust/Go helpers (build chain), shell scripts (journal and INI surgery are too delicate) |
| D-11 | **Every shell bind goes through `global` shortcuts**, except locking. | No process per keypress; one source of truth for actions. Locking forks on purpose so it works with the shell down. | `exec aptus msg` everywhere (slower, but it is P-01's fallback) |
| D-12 | **Nothing changes in `hyprland.lua` without a shown diff and Lenno's yes.** All aptus Lua lives in `~/.config/hypr/aptus/`, loaded by one marked block. | The file is Lenno's; removing the block returns to plain Hyprland. | rewriting the file, or generating the whole config |
| D-13 | **Never suspend on idle**; screen off and lock only. | Suspend should be a decision, not a timeout (open lids on a desk, long builds). | suspend after N minutes |
| D-14 | **Notifications live in the notch and Today only**, no corner popups. | One place for "now", one for "what happened"; nothing covers windows' content corners. | a popup stack in a corner (Noctalia's way) |
| D-15 | **Network only for weather and calendars, and only when configured.** | The shell should work fully offline and leak nothing. | online currency rates, online search suggestions while typing |
| D-16 | **The greeter stays as it is.** | It is shared by both sessions; changing it would change Umbriel's login. | an aptus greeter (v1 tried; leftovers listed in [11](11-roadmap.md) §4) |
| D-17 | **Graceful logout** asks every window to close and stops at the first refusal. | No lost work; a forced logout is one explicit click away. | Hyprland `exit` immediately (today's `Super+M`) |
| D-18 | **Recording via VAAPI on the Intel GPU** (`renderD128`), never NVENC. | The NVIDIA GPU stays asleep; battery life matters more than encoder speed. | NVENC, software x264 (not in `ffmpeg-free`) |

## 2. Decided by Lenno (2026-11-07)

Lenno accepted every recommendation. The design already uses these answers everywhere.

| ID | Question | Decision |
|---|---|---|
| D-01 | Lid closed: lock or suspend? | **Lock**: lock and turn the panel off; with an external monitor, disable the internal panel (`power.lidAction = lock`). Suspend only from the session sheet when `power.allowSuspend` is on (off by default). |
| D-02 | Spotify and LibreOffice in aptus colours? | **No**: they keep Noctalia's colours in Hyprland (`isolation.bakeTargets = []`). |
| D-03 | Untrack Noctalia's generated files in `~/dotfiles`? | **Yes**: the kitty theme, `hyprtoolkit.conf`, the fastfetch theme and `nvim/lua/matugen.lua` (plus any other Noctalia artifact found tracked) go into `.gitignore` and are removed from the index with `git rm --cached`; the files stay on disk. Done in stage S2 as a local commit in `~/dotfiles`; pushing `~/dotfiles` still needs Lenno's go. |
| D-05 | Defaults | **Super tap opens Spotlight; Ember (dark); jade.** |
| D-19 | UI language | **English.** |
| D-20 | Hyprland's look in the aptus session | **Yes**: gaps, accent borders, aptus animations and no default wallpaper, inside the aptus block only. This deliberately departs from "Hyprland defaults except keys, keyboard and monitors" for the aptus session. |
| D-21 | Weather place | **Berlin, Germany** (lat 52.520, lon 13.405); also drives sunrise/sunset for `auto` mode and night light. |
| D-22 | Commit and push the design | **Done**: committed and pushed on `v2-design`. The `v1-final` tag is created and pushed by the implementing agent in stage S1. |
