# aptus-theme-apps: generated from theme/tokens.json, do not edit (run aptus-theme-apps again)
set -gx STARSHIP_CONFIG "{{starship_path}}"
set -gx BAT_THEME ansi
if test -f "{{fastfetch_config}}"
    alias fastfetch='command fastfetch --config "{{fastfetch_config}}"'
end
