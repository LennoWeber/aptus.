"""hypr/*.lua: binds cover every global shortcut (lock is bound through exec, overview-open/-close
through the gestures), descriptions well-formed, init.lua's gen defaults equal tokens.json."""
from __future__ import annotations

# TODO(phase): run hypr/binds.lua under /usr/bin/luajit with a stub `hl` that records bind() calls
#   (no lua 5.4 is installed; 09's binds use no 5.4-only syntax).



def test_every_shortcut_bound() -> None:
    raise NotImplementedError


def test_descriptions_format() -> None:
    raise NotImplementedError


def test_gen_defaults_match_tokens() -> None:
    raise NotImplementedError
