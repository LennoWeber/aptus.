# PHASES.md — aptus v2 work log

The work log for aptus v2, from stage S0 on. The v1 log is in the `v1-final` tag.

- Spec: `design/` (source of truth). Plan: `design/11-roadmap.md` §2. Brief: `design/handoff-prompt.md`.
- Workflow: every stage runs the seven phases of `phasen-entwicklung` back to back (no waiting for
  "weiter"); one commit per phase (`S<n> <area>: phase <k>: …`); each phase is logged here with
  what was done, how it was checked and the result. Reviews after phases 2, 3, 4, 6, 7 are done by
  a fresh subagent that sees only the goal, the phase rules and the diff.
- Branch `v2` (from `v2-design`); `v1-final` = `337d6c7`.

## Status

| Wave | Stages | State |
|---|---|---|
| 0 | S0 probes | P-01, P-03, P-11, P-23 pass; P-14 half; the rest run with their stage |
| 1 | S1 Foundation | next |
| 2 | S2 Isolation ‖ S3 Bar and notch | — |
| 3 | S4 Spotlight ‖ S5 Deck ‖ S6 Session ‖ S7 Windows | — |
| 4 | S8 Time and attention ‖ S9 Capture ‖ S10 Settings and gallery | — |
| 5 | S11 Finish, acceptance | — |

## Open items for Lenno

- Physical-key check of P-01 (virtual keyboards cannot fire binds): during the S1 hands-on round.
- P-22: no finger is enrolled; enrolling is Lenno's choice (machine-wide, Umbriel would see it).

---

## S0 · Probes (2026-11-07)

**Setup.** `v2` branched from `v2-design` (`833275c`), `v1-final` tagged on `337d6c7`, both pushed.

**What ran.** A nested Hyprland with a temporary `HOME`, a private D-Bus (`dbus-run-session`) and
`HYPRLAND_NO_SD_VARS=1` (so the real user manager's environment is never touched), the full
`09-hyprland.md` Lua, and a 60-line probe shell. Results with details: `design/probes.md`.

| Probe | Result | Consequence |
|---|---|---|
| P-01 | pass: `aptus:*` listed; dispatch → handler median 0.8 ms | binds use `hl.dsp.global` |
| P-03 | pass; every rule effect, expression, dispatcher and option accepted | **spec fix:** `bind()` in 09 §7 unbinds a chord only once (the Super hold bind deleted the tap bind) and no longer mutates the shared `L`/`R` option tables |
| P-11 | pass: mask click-through, away catcher, None ↔ Exclusive without remap (30 toggles) | D-08 stays |
| P-23 | pass: `settings.watchFiles` from `APTUS_DEV`, positive control reloads | `aptus dev` sets `APTUS_DEV=1` |
| P-14 | first half passes: the lid block inhibitor is granted to a transient user unit without polkit | second half (lid → lock) in S6 with Lenno |
| P-22 | not runnable: no finger enrolled | runs in S6 if Lenno enrols one |

**Findings for the harness** (recorded in probes.md, used by S1): virtual keyboards never fire
Hyprland binds, so e2e tests dispatch `hl.dsp.global` over the socket; pointer input comes from a
stdlib Wayland virtual-pointer client (`tests/e2e/vpointer.py`), never `ydotool`; `qs ipc` only
sees instances on the caller's `WAYLAND_DISPLAY`.

**Checked by:** each probe's pass condition from 11-roadmap §1, measured as listed; P-03 also
checked negatively (an unknown field is reported, so silence means acceptance).
