"""The `aptus` command: msg, doctor, logs, theme, lease, dev, version (07-architecture §2)."""
from __future__ import annotations

import argparse
from collections.abc import Sequence


VERSION = "2.0.0-dev"


def parser() -> argparse.ArgumentParser:
    raise NotImplementedError


def cmd_logs(follow: bool, component: str | None) -> int:
    """journalctl --user -t aptus-shell -t aptus-session -u 'aptus-*' [-f]."""
    raise NotImplementedError


def cmd_dev(argv: Sequence[str]) -> int:
    """Run the shell in the foreground with APTUS_DEV=1 (live reload, P-23)."""
    raise NotImplementedError


def main(argv: Sequence[str] | None = None) -> int:
    raise NotImplementedError
