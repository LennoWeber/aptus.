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


# Exit codes of `aptus msg` (the Super+L chain relies on a non-zero exit for every failure).
EXIT_OK = 0
EXIT_ERROR = 1          # the shell answered "error: …", an empty answer, or a qs ipc error text
EXIT_USAGE = 2          # unknown target/function, wrong number of arguments
EXIT_NO_SHELL = 3       # no shell instance (qs ipc exits 255)
EXIT_TIMEOUT = 4        # the shell did not answer in time (frozen)
TIMEOUT = 2.0           # seconds

# qs ipc call reports these on stdout with exit code 0 (phase-5 probe, S1).
QS_ERRORS = ("Too few arguments", "Function not found", "Unable to parse argument",
             "No running instances", "Target not found")


def classify(returncode: int, output: str) -> int:
    """Map qs's exit code and output to an EXIT_* code (qs reports most errors with exit 0)."""
    raise NotImplementedError


def call(paths: Paths, target: str, function: str, args: Sequence[str],
         timeout: float = TIMEOUT) -> tuple[int, str]:
    """Run the call (qs ipc show first to pad optional arguments). → (EXIT_* code, answer)."""
    raise NotImplementedError


def main(argv: Sequence[str]) -> int:
    raise NotImplementedError
