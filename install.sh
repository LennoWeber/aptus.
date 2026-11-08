#!/usr/bin/bash
# install.sh: non-destructive install of aptus v2 (11-roadmap §4, 09-hyprland §1, 02 §11).
# Lists every change outside the repo, shows the hyprland.lua diff, asks per group and applies
# only after "y"; --uninstall is the reverse.
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

if [[ "${APTUS_TEST:-}" == "1" ]]; then
    tmp="${TMPDIR:-/tmp}"
    case "$(readlink -f "${HOME:-/}")/" in
        "$(readlink -f "$tmp")"/?*/) ;;
        *) echo "install.sh: APTUS_TEST=1 needs a temporary HOME under $tmp, not $HOME" >&2; exit 2 ;;
    esac
fi

# -I ignores PYTHONPATH, so the package path is put on sys.path explicitly.
exec /usr/bin/python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); from aptus.install import main; sys.exit(main(sys.argv[2:]))' "$repo/lib" "$@"
