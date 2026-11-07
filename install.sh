# install.sh: non-destructive install of aptus v2 (11-roadmap §4, 09-hyprland §1, 02 §11).
# TODO(phase): #!/usr/bin/bash, set -euo pipefail; refuse under APTUS_TEST unless HOME is a temp dir;
#   exec python3 -I -m aptus.install "$@" with PYTHONPATH=<repo>/lib (lists, shows the
#   hyprland.lua diff, asks per group, applies only after "y"; --uninstall the reverse).
