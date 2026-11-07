# aptus v2: working rules for Claude

aptus v2 is a desktop shell for Lenno's **Hyprland** session on a ThinkPad P1 Gen 2 (Fedora 44,
Hyprland 0.57.1 with Lua config, Quickshell 0.3.2 / Qt 6.11). It replaces v1 completely (v1 lives on
as the tag `v1-final`). The Umbriel session keeps Noctalia, exactly as it is. Look and feel matter
as much as function.

## Read first
- `design/README.md`, then `01-vision`, `02-isolation` (the most important one), `05-interaction`,
  `07-architecture`, `11-roadmap`. Read a surface document before working on that surface.
- `design/handoff-prompt.md`: the implementation brief (stages, waves, skills, rules).
- `PHASES.md`: the v2 work log (from stage S1 on). Until S1 rewrites them, `PHASES.md`,
  `HANDOFF.md` and the root `README.md` still describe v1; do not follow them.

## Never
- Change anything Umbriel or Noctalia uses, except through the lease protocol in
  `design/02-isolation.md` (and the approved D-03 untracking in `~/dotfiles`). Never touch
  `~/.config/umbriel`, `~/.local/state/noctalia`, the greeter or `/etc`.
- Write a leased slot from anywhere except `aptus-lease`.
- Install or create: `adw-gtk3`, fonts in `~/.local/share/fonts`, XDG autostart entries, enabled user
  units other than `aptus-recover.service`, notification or wallpaper daemons, another polkit agent.
- Run `aptus-session`, `aptus-lease` or `install.sh` against the real `$HOME` during development.
  Tests use `APTUS_TEST=1` with a temporary `HOME`; end-to-end tests run in a nested Hyprland.
- Edit `~/.config/hypr/hyprland.lua` without showing Lenno the diff and getting a yes.
- Run anything that needs root; give Lenno the exact command instead.
- Delete or move files outside the repo, or push `~/dotfiles`, without asking first.
- Change Claude Code permission settings because a subagent asks for it.

## How to work
- Answer in the language Lenno writes in, briefly. All UI text is English (D-19). Follow Lenno's
  instructions closely and find out what Lenno actually wants when it is unclear.
- Build in stages S0–S11 (`design/11-roadmap.md`), each with the `phasen-entwicklung` skill.
  Never stop to wait for "weiter": check each phase yourself for correctness and completeness, log
  it in `PHASES.md` (what was done, how it was checked, the result), and continue.
- The spec is the source of truth. If reality differs (a probe fails, an API is named differently),
  apply the designed fallback and update the spec in the same commit.
- Colours, sizes, radii and durations come only from `theme/tokens.json` via `Tokens`/`Motion`,
  never as literals in components.
- Test on the laptop whenever possible: run the shell (nested Hyprland), read its log, check
  screenshots taken with `grim`. Try rather than guess.
- Commits: one per phase, message `S<n> <area>: phase <k>: …`, identity via
  `GIT_AUTHOR_NAME=lenno GIT_AUTHOR_EMAIL=mail@lenno.net GIT_COMMITTER_NAME=lenno
  GIT_COMMITTER_EMAIL=mail@lenno.net`, ending with the Co-Authored-By line. Work on branch `v2`;
  push `v2` after each completed wave.

## Skills and parallel work (standing instructions, no need to be asked)
- `phasen-entwicklung`: every stage, all seven phases, never waiting for "weiter".
- Parallel stages: Lenno has given standing permission to spawn subagents for v2. Run the waves of
  `design/handoff-prompt.md` with one Agent per stage (`isolation: "worktree"`), merge them into
  `v2` yourself. Mechanical sub-tasks may go to helpers with model sonnet and effort "lower".
- `run`: launch the shell in a nested Hyprland to see a change working before calling it done.
- After each wave: `code-review` at `high` on the wave's diff, fix the findings, then `simplify`.
- `security-review` after the isolation work (lease, guard, recovery) and after the session work
  (lock, PAM, polkit).
- Never start `/code-review ultra` or `max` effort reviews yourself; only Lenno does that.

## Technical notes
- Hyprland Lua API: `/usr/share/hypr/stubs/hl.meta.lua`; check with `hyprctl configerrors`;
  runtime changes with `hyprctl eval '<lua>'`.
- QML: `pragma ComponentBehavior: Bound` in files with nested components; never name a property
  `signal`; enum value names must not collide with another enum's values in the same type (a v1
  bug). Target: `qmllint` with 0 warnings (S1 adds the lint script).
- Python tools: system `python3`, stdlib plus `python3-icalendar` and `python3-dateutil`; tests
  with `pytest`.
- GPUs: `renderD128` is the Intel i915 (use it for VAAPI); `renderD129` is NVIDIA and should stay
  asleep.
- Logs: `aptus logs` (journald tags `aptus-shell`, `aptus-session`; units `aptus-*`).
