"""Linux inotify through ctypes (stdlib only) for aptus-guard (02 §7): a few files watched by name
through their directories, so a file replaced by rename (logind's user record, aptus.atomic's
writes) keeps being seen."""
from __future__ import annotations

import ctypes
import os
import struct
from collections.abc import Iterable
from pathlib import Path

IN_ATTRIB = 0x4
IN_CLOSE_WRITE = 0x8
IN_MOVED_FROM = 0x40
IN_MOVED_TO = 0x80
IN_CREATE = 0x100
IN_DELETE = 0x200
IN_DELETE_SELF = 0x400
IN_MOVE_SELF = 0x800
IN_Q_OVERFLOW = 0x4000
IN_IGNORED = 0x8000
IN_ONLYDIR = 0x1000000
# A watched name is created, written, renamed onto or away, removed or touched.
CHANGES = IN_ATTRIB | IN_CLOSE_WRITE | IN_MOVED_FROM | IN_MOVED_TO | IN_CREATE | IN_DELETE
# The directory itself goes away: its watch ends (IN_IGNORED follows).
GONE = IN_DELETE_SELF | IN_MOVE_SELF | IN_IGNORED

_EVENT = struct.Struct("iIII")          # struct inotify_event: wd, mask, cookie, len (+ name)


class Files:
    """One non-blocking inotify fd watching `files` through their directories. `fd` goes into
    a poll set; `changed()` drains it. `watching` is False when inotify or a directory could not
    be watched (it does not exist yet, say) or a directory went away: the caller polls then."""

    def __init__(self, files: Iterable[Path]) -> None:
        self.fd = -1
        self.watching = False
        self._names: dict[int, set[str]] = {}
        try:
            libc = ctypes.CDLL(None, use_errno=True)
            fd = libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
        except (OSError, AttributeError):
            return
        if fd < 0:
            return
        self.fd = fd
        by_dir: dict[Path, set[str]] = {}
        for f in files:
            by_dir.setdefault(f.parent, set()).add(f.name)
        for d, names in by_dir.items():
            wd = libc.inotify_add_watch(fd, os.fsencode(d), CHANGES | GONE | IN_ONLYDIR)
            if wd < 0:
                return
            self._names.setdefault(wd, set()).update(names)
        self.watching = True

    def changed(self) -> bool:
        """Read every pending event; True when one concerns a watched file, the kernel's queue
        overflowed (anything may have changed) or a directory went away (watching is then
        False)."""
        hit = False
        while True:
            try:
                buf = os.read(self.fd, 64 * 1024)
            except BlockingIOError:
                return hit
            except OSError:
                self.watching = False
                return True
            off = 0
            while off + _EVENT.size <= len(buf):
                wd, mask, _cookie, size = _EVENT.unpack_from(buf, off)
                name = buf[off + _EVENT.size:off + _EVENT.size + size].split(b"\0", 1)[0]
                off += _EVENT.size + size
                if mask & GONE:
                    self.watching = False
                    hit = True
                elif mask & IN_Q_OVERFLOW or os.fsdecode(name) in self._names.get(wd, ()):
                    hit = True

    def close(self) -> None:
        if self.fd >= 0:
            os.close(self.fd)
            self.fd = -1
            self.watching = False
