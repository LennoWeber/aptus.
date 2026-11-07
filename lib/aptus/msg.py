"""`aptus msg <target> <function> [args…]`: wraps `qs -p <repo>/shell ipc call …` (07 §7)."""
from __future__ import annotations

from collections.abc import Sequence

from .paths import Paths


# Function names that are reserved in JavaScript and therefore spelled differently in the
# shell's IpcHandlers (07 §7).
ALIASES = {("dnd", "for"): "forDuration"}


def parse_show(text: str) -> dict[str, dict[str, int]]:
    """`qs ipc show` output → {target: {function: number of arguments}}."""
    raise NotImplementedError


def build(paths: Paths, target: str, function: str, args: Sequence[str],
          arity: int | None) -> list[str]:
    """The `qs -p <shell> ipc call` argv; missing optional arguments are padded with ""."""
    raise NotImplementedError


def call(paths: Paths, target: str, function: str, args: Sequence[str]) -> tuple[int, str]:
    """Run the call. → (exit code, answer). Exit 3 when no shell instance runs."""
    raise NotImplementedError


def main(argv: Sequence[str]) -> int:
    raise NotImplementedError
