# install.sh: non-destructive install of aptus v2 (11-roadmap §4, 09-hyprland §1, 02 §11).
# TODO(phase): #!/usr/bin/bash (mode 755), set -euo pipefail; under APTUS_TEST refuse unless HOME
#   differs from the passwd home (getent passwd "$USER").
# TODO(phase): PYTHONPATH=<repo>/lib exec python3 -s -m aptus.install "$@" (not -I: it ignores
#   PYTHONPATH). It lists, shows the hyprland.lua diff, asks per group, applies after "y".
