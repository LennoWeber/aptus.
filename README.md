# aptus

A desktop shell for the **Hyprland** session on a ThinkPad P1 Gen 2 (Fedora 44, Hyprland 0.57 with
Lua config, Quickshell 0.3.2 / Qt 6.11). One quiet frame around the screen, a notch that grows into
Spotlight, Today, the Switcher and toasts, a Deck of quick settings, an Overview, capture, focus
sessions, a lock screen and a settings app. Everything works with keyboard, mouse and touch.

This is **aptus v2**, a complete rewrite. v1 lives on as the tag `v1-final`. The Umbriel session
keeps Noctalia exactly as it is: nothing aptus does reaches it (see
[design/02-isolation.md](design/02-isolation.md)).

Status: being built in stages S0–S11 ([design/11-roadmap.md](design/11-roadmap.md)); the work log is
[PHASES.md](PHASES.md).

## Design

`design/` is the full specification and the source of truth for the code. Start with
[design/README.md](design/README.md); the most important document is
[02-isolation](design/02-isolation.md).

| Document | What it answers |
|---|---|
| [01 Vision](design/01-vision.md) | what aptus is for, the principles |
| [02 Isolation](design/02-isolation.md) | how Hyprland gets aptus's look while Umbriel stays Noctalia's |
| [03 Visual language](design/03-visual-language.md) | every colour, type, icon, geometry and state token |
| [04 Motion](design/04-motion.md) | durations, curves, springs, choreography, the animation catalogue |
| [05 Interaction](design/05-interaction.md) | surfaces, focus, the Esc ladder, keymap, multi-monitor |
| [surfaces/](design/surfaces/) | one document per surface |
| [07 Architecture](design/07-architecture.md) | processes, startup, QML structure, services, IPC, tests |
| [08 Theming](design/08-theming.md) | palette resolution and every app target |
| [09 Hyprland](design/09-hyprland.md) | the Lua profile: look, animations, rules, binds |
| [10 Settings](design/10-settings.md) | every setting key |
| [11 Roadmap](design/11-roadmap.md) | probes, stages, acceptance, migration from v1 |
| [12 Decisions](design/12-decisions.md) | decision log |

## Install

```sh
./install.sh               # lists every change outside the repo, asks per group, then applies
./install.sh --uninstall   # the reverse (links removed, removed lines put back on request)
```

`install.sh` creates aptus's folders, links `~/.config/hypr/aptus` → `hypr/` and
`~/.local/bin/aptus*` → `bin/`, moves v1 leftovers (never deletes them) to
`~/.local/state/aptus-v1-backup/<date>/`, and edits `~/.config/hypr/hyprland.lua` only after showing
the diff (a backup goes to `~/.local/state/aptus/install/` first). It never installs packages, fonts,
autostart entries or system files and never needs root.

## Use

```sh
aptus msg <target> <function> [args…]   # talk to the running shell, e.g. aptus msg shell state
aptus logs [-f] [component]             # the journal of the shell, the session tools and units
aptus doctor [config|deps]              # check settings and dependencies
aptus dev on|off                        # live reload of the shell while editing QML
```

## Develop

```sh
tests/run          # pytest tests/unit, qmltestrunner on tests/qml, tests/lint.sh (qmllint, 0 warnings)
tests/run e2e      # the same plus the nested-Hyprland end-to-end tests
```

Tests never touch the real home: unit tests run with `APTUS_TEST=1` and a temporary `HOME`, the
end-to-end tests in a nested Hyprland with its own `HOME` and session bus. Set `APTUS_PYTEST` to use
another pytest (e.g. `APTUS_PYTEST="venv/bin/python -m pytest"`).

Layout: `shell/` (QML: `core/`, `components/`, `services/`, `surfaces/`, `registry/`, `windows/`),
`lib/aptus/` (the Python session tools behind `bin/`), `hypr/` (the Lua profile), `theme/tokens.json`
(every visual token), `tests/`.

## License

MIT, see [LICENSE](LICENSE).
