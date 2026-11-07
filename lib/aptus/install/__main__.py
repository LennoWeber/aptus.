"""python3 -m aptus.install (called by install.sh)."""
import sys

from . import main

sys.exit(main(sys.argv[1:]))
