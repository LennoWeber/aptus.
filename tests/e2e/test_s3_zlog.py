"""S3 acceptance, a clean log: after every other e2e test (this file sorts last) the test shell's
log has no warning or error, and no invariant fired. One line is Qt's, not aptus': in the nested
session Qt's platform services find the portal's app ID already taken (it is the same in S1)."""
from __future__ import annotations

import re

from nested import Nested

KNOWN = [re.compile(r"qt\.qpa\.services.*Failed to register with host portal")]


def test_shell_log_has_no_warnings(nested: Nested) -> None:
    log = (nested.home / "aptus-shell.log").read_text(errors="replace")
    bad = [line for line in log.splitlines()
           if re.search(r"\b(WARN|ERROR|CRIT|FATAL)\b|invariant", line) and not any(k.search(line) for k in KNOWN)]
    assert not bad, "\n".join(bad[:20])
