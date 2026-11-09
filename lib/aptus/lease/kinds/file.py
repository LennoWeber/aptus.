"""Kind `file` (02 §5.5): bytes + mode; write = temp + rename in the slot's own (resolved)
directory with the mode of `before`; restore = the bytes of slots/<id>.before, or unlink when the
artifact did not exist. A symlinked slot is written through to its target, never replaced."""
from __future__ import annotations
