# Handoff: the implementation brief

## How to start the session

```sh
cd ~/Code/Projekte/aptus
git switch v2-design
claude
```

In Claude Code: `/model` → **Opus 5.5**, `/effort` → **xhigh**, then paste the prompt below.

| Who | Model | Effort | Why |
|---|---|---|---|
| Main session (orchestrator, S0, S1, S11, merges, reviews) | Opus 5.5 | xhigh | long autonomous run; the isolation code edits files Umbriel reads, so mistakes are expensive |
| Stage subagents (S2–S10, one per worktree) | Opus 5.5 (inherited) | inherited | each stage is a full feature with design decisions to honour |
| Mechanical helpers inside a stage (theme templates for 36 targets, golden files, `emoji.json`, `known-binds.json`, schema from 10-settings) | Sonnet 5.5 | lower | pattern work that checks itself against the spec |

`max` is not needed. It costs much more per turn, and the spec already fixes the hard decisions.

## Skills to use

| Skill / tool | When |
|---|---|
| `phasen-entwicklung` | every stage, all seven phases, without waiting for "weiter" |
| Agent tool with `isolation: "worktree"` | parallel stages (there is no separate parallel-development skill; the prompt below gives explicit permission to spawn) |
| `run` | to launch the shell in a nested Hyprland and see a change working |
| `code-review` at `high` | once per wave, on the merged diff |
| `simplify` | once per wave, after the review fixes |
| `security-review` | after wave 2 (lease, guard, recovery) and wave 3 (lock, PAM, polkit) |
| `/code-review ultra` | optional, started by Lenno before the final merge (billed, cloud) |

## The prompt

```text
You are implementing aptus v2, a Quickshell desktop shell for my Hyprland session, in
~/Code/Projekte/aptus. The complete design is in design/ (branch v2-design). It is the source of
truth, and every open question in it has been decided (design/12-decisions.md §2). Build it exactly,
stage by stage, until every acceptance check in design/11-roadmap.md §3 passes. Do not redesign.
Where reality differs from the spec (a failed probe, a differently named API), use the fallback the
spec gives and update the spec in the same commit.

Read first: CLAUDE.md (the rules; they bind you and every subagent), design/README.md, 01, 02, 05,
07, 11. Read each surface document before its stage.

Setup
1. git switch -c v2 v2-design. Tag main's 337d6c7 as v1-final. Push the tag and the v2 branch.
2. Start PHASES.md as the v2 work log (the v1 content goes away with the v1 removal in S1).

Plan (waves; "‖" = parallel)
- Wave 0, you: S0. Run the probes that need no aptus code first (P-01, P-03, P-11, P-23), the rest
  when the stage that needs them starts. Record every result in design/probes.md. For probes that
  need my hands (lid, fingerprint, logging out and in, power-off), give me exact numbered steps and
  keep working on other things while I do them.
- Wave 1, you: S1 Foundation. Besides the roadmap contents, S1 lays down every shared registry so
  later stages only add files in their own folders:
  - the full settings schema (every key in design/10-settings.md);
  - Tokens and Motion with every token from design/03 and design/04;
  - every GlobalShortcut name and IpcHandler target from design/07 §7, as stubs;
  - the SurfaceManager with all surface ids and the transition rules of design/07 §5;
  - the component library of design/03 §9;
  - the complete hypr/ Lua of design/09;
  - paths, atomic writes and logging;
  - the test harness: pytest, qmltestrunner, and a nested Hyprland with APTUS_TEST=1.
  Merge into v2 and push.
- Wave 2: S2 Isolation ‖ S3 Bar and notch.
- Wave 3: S4 Spotlight ‖ S5 Deck ‖ S6 Session ‖ S7 Windows.
- Wave 4: S8 Time and attention ‖ S9 Capture ‖ S10 Settings and gallery.
- Wave 5, you: S11 Finish, then the full acceptance list.

Every stage uses the phasen-entwicklung skill, all seven phases, never waiting for "weiter". Commit
once per phase and log each phase in PHASES.md with how you checked it and the result.

Parallel work: you have my permission to spawn subagents. For each parallel stage, spawn one Agent
with isolation "worktree" (general-purpose, same model). Its brief names:
- the stage and the design documents to read;
- the folders it owns;
- the shared files it must not edit (registries, SurfaceManager, schema, hypr/binds.lua). If it
  needs a change there, it reports the change and you make it;
- the stage's acceptance checks;
- that CLAUDE.md applies to it.
Mechanical sub-tasks (the 36 theme templates, golden files, emoji.json, known-binds.json) may go to
helper agents with model sonnet and effort "lower".

After each wave:
1. Merge every worktree into v2, resolving conflicts yourself.
2. Run all tests and qmllint (0 warnings).
3. Run /code-review high on the wave's diff and fix the findings.
4. Run the simplify skill.
5. After waves 2 and 3, also run security-review.
6. Push v2 and give me a short report: what is done, test results, probe outcomes, and what I
   should try on the laptop.

Stop and ask me only for:
- any root command (give me the exact command);
- the hyprland.lua diff from install.sh;
- moving v1 leftovers outside the repo;
- pushing ~/dotfiles.
After wave 2, I install and run the isolation round-trip test (design/02-isolation.md §10). Give me
the exact steps. Never run install.sh, aptus-session or aptus-lease against my real home yourself.
While I test, carry on with wave 3 in nested Hyprland, but merge nothing that changes isolation
code until I report that the round-trip passed.

Umbriel and Noctalia must stay byte-for-byte as they are. Nothing outside the Hyprland profile may
change except through the lease protocol and the approved D-03 untracking in ~/dotfiles (a local
commit only). If you are unsure whether something could leak into Umbriel, don't do it; ask me.
```
