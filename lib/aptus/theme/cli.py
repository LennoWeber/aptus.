"""aptus-theme render | apply | targets (08 §4–§6); also `aptus theme …`.

    render [--inputs JSON]   write a generation (inputs from settings.json when omitted)
    apply  [--inputs JSON]   render, then lease update / scope / own / hooks; JSON report on stdout
    targets [--json]         every target with its mechanism, state and the coverage report
"""
from __future__ import annotations

import argparse
from collections.abc import Sequence

from ..paths import Paths


def parser() -> argparse.ArgumentParser:
    # TODO(S2): subcommands render/apply [--inputs JSON], targets [--json].
    raise NotImplementedError


def cmd_render(paths: Paths, inputs_json: str | None) -> int:
    # TODO(S2): inputs.from_json or from_settings; targets.load; render.render; print gen n.
    raise NotImplementedError


def cmd_apply(paths: Paths, inputs_json: str | None) -> int:
    # TODO(S2): apply.apply(…, env signature); print report_json; exit 1 only when the render
    #   itself failed.
    raise NotImplementedError


def cmd_targets(paths: Paths, as_json: bool) -> int:
    """One line per target: id, mechanism, installed or not, and the coverage of Noctalia's
    enabled templates ("uncovered: <id>" lines)."""
    # TODO(S2): manifest; active(); coverage(noctalia.enabled(paths), slot paths).
    raise NotImplementedError


def main(argv: Sequence[str]) -> int:
    # TODO(S2): log.setup('theme'); paths.get(); require_safe_home (exit 3); dispatch.
    raise NotImplementedError
