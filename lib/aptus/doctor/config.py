"""`aptus doctor config`: settings.json against the schema (07-architecture §8)."""
from __future__ import annotations


def check(paths: Paths) -> list[Check]:
    """settings.json parses, has "v": 2, every key is known and valid (same rules as
    shell/core/js/config.js); a v1 file is reported as ignored, not as an error."""
    raise NotImplementedError


def validate(schema: dict, key: str, value: object, home: str) -> str | None:
    """None when valid, else the message (the same wording as the shell)."""
    raise NotImplementedError
