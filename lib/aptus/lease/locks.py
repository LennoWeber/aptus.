"""The one flock helper behind the lease lock (ops.lock, lease/lock) and the theme lock
(render.lock, theme/lock): exclusive, re-entrant within one thread, given up after a timeout."""
from __future__ import annotations

import fcntl
import os
import threading
import time
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from pathlib import Path

_held: dict[tuple[str, int], list[int]] = {}   # (lock path, thread) → [fd, depth]


@contextmanager
def exclusive(path: Path, timeout: float, busy: Callable[[], Exception]) -> Iterator[None]:
    """flock(path, LOCK_EX), created 0600 when missing. A thread that holds it already only counts
    the nesting (take calls recover, apply holds the theme lock while render takes it again); another
    thread or process waits. When it stays taken for `timeout` seconds (0: tried once), `busy()` is
    raised."""
    key = (str(path), threading.get_ident())
    if key in _held:
        _held[key][1] += 1
        try:
            yield
        finally:
            _held[key][1] -= 1
        return
    fd = os.open(path, os.O_RDWR | os.O_CREAT | os.O_CLOEXEC, 0o600)
    end = time.monotonic() + timeout
    while True:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            break
        except BlockingIOError:
            if time.monotonic() > end:
                os.close(fd)
                raise busy() from None
            time.sleep(0.05)
    _held[key] = [fd, 1]
    try:
        yield
    finally:
        del _held[key]
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)
