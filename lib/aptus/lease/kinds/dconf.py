"""Kind `dconf` (02 §5.5): `dconf read KEY` (empty = not set), `dconf write KEY VALUE`, restore with
`dconf write KEY BEFORE` or `dconf reset KEY`. Only the fixed key set of 02 §5.5 is ever touched;
`gtk-theme` is recorded and never written. dconf runs through lease.system (a fake under test)."""
from __future__ import annotations
