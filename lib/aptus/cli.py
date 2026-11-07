"""The `aptus` command: msg, doctor, logs, theme, lease, dev, version (07-architecture §2)."""
from __future__ import annotations

import argparse
from collections.abc import Sequence


VERSION = "2.0.0-dev"


def parser() -> argparse.ArgumentParser:
    raise NotImplementedError


def journal_queries(component: str | None) -> list[list[str]]:
    """The journalctl argument lists for `aptus logs`: journalctl ANDs -t with -u, so the tags
    (aptus-shell, aptus-session, aptus-supervise) and the units (aptus-*) are two queries, merged
    by timestamp (-o json). `component` narrows to one tag or unit."""
    raise NotImplementedError


def cmd_logs(follow: bool, component: str | None) -> int:
    """Print the merged journal (07 §11); with follow, both queries stream (-f) and lines are
    printed as they arrive."""
    raise NotImplementedError


def cmd_dev(on: bool) -> int:
    """`aptus dev [on|off]`: create/remove <runtime>/dev and restart the supervised shell; the
    supervisor starts qs with APTUS_DEV=1 while the flag exists (live reload, P-23)."""
    raise NotImplementedError


def main(argv: Sequence[str] | None = None) -> int:
    raise NotImplementedError
