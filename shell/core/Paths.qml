pragma Singleton
// Every path the shell uses (07-architecture §2). Resolved once from the environment;
// under APTUS_TEST=1 everything derives from HOME (the harness points HOME at a temp dir).
import QtQuick
import Quickshell
import "js/config.js" as ConfigLib

Singleton {
    id: root

    // An XDG base directory: the variable when set (and, under APTUS_TEST, inside HOME), else HOME + rel.
    function _xdg(name: string, rel: string): string {
        const v = Quickshell.env(name);
        const s = v === undefined || v === null ? "" : String(v);
        if (s !== "" && s.charAt(0) === "/" && (!test || s === home || s.indexOf(home + "/") === 0)) return s.replace(/\/+$/, "");
        return home + "/" + rel;
    }
    readonly property bool test: Quickshell.env("APTUS_TEST") === "1"
    readonly property bool dev: Quickshell.env("APTUS_DEV") === "1"
    readonly property string home: String(Quickshell.env("HOME") || "").replace(/\/+$/, "")
    readonly property string configHome: _xdg("XDG_CONFIG_HOME", ".config")      // $XDG_CONFIG_HOME
    readonly property string stateHome: _xdg("XDG_STATE_HOME", ".local/state")       // $XDG_STATE_HOME
    readonly property string cacheHome: _xdg("XDG_CACHE_HOME", ".cache")       // $XDG_CACHE_HOME
    readonly property string dataHome: _xdg("XDG_DATA_HOME", ".local/share")        // $XDG_DATA_HOME

    readonly property string config: configHome + "/aptus"          // ~/.config/aptus
    readonly property string state: stateHome + "/aptus"           // ~/.local/state/aptus
    readonly property string cache: cacheHome + "/aptus"           // ~/.cache/aptus
    readonly property string runtime: (test || !Quickshell.env("XDG_RUNTIME_DIR") ? home + "/.aptus-run" : String(Quickshell.env("XDG_RUNTIME_DIR")).replace(/\/+$/, "")) + "/aptus"         // $XDG_RUNTIME_DIR/aptus ($HOME/.aptus-run/aptus in tests and without XDG_RUNTIME_DIR, as paths.py)

    readonly property string shellDir: String(Quickshell.shellDir).replace(/\/+$/, "")        // <repo>/shell
    readonly property string repo: shellDir.replace(/\/[^/]*$/, "")            // <repo>
    readonly property string bin: repo + "/bin"             // <repo>/bin
    readonly property string tokensFile: repo + "/theme/tokens.json"      // <repo>/theme/tokens.json
    readonly property string schemaFile: shellDir + "/config/settings-schema.json"      // <repo>/shell/config/settings-schema.json
    readonly property string assets: shellDir + "/assets"          // <repo>/shell/assets

    readonly property string settingsFile: config + "/settings.json"    // ~/.config/aptus/settings.json
    readonly property string calendarsFile: config + "/calendars.json"   // ~/.config/aptus/calendars.json
    readonly property string wallpaperState: state + "/wallpaper.json"  // ~/.local/state/aptus/wallpaper.json
    readonly property string uiState: state + "/ui.json"         // ~/.local/state/aptus/ui.json
    readonly property string lockedMarker: state + "/locked"    // ~/.local/state/aptus/locked
    readonly property string leaseJournal: state + "/lease/journal.json"    // ~/.local/state/aptus/lease/journal.json
    readonly property string themeCurrent: state + "/theme/current"    // ~/.local/state/aptus/theme/current
    readonly property string hyprState: state + "/hypr"       // ~/.local/state/aptus/hypr
    readonly property string restartFlag: runtime + "/restart"     // <runtime>/restart
    readonly property string introFlag: runtime + "/intro." + String(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "none")       // <runtime>/intro.<HYPRLAND_INSTANCE_SIGNATURE>
    readonly property string guardState: runtime + "/guard.state"      // <runtime>/guard.state
    readonly property string clipChanged: runtime + "/clip.changed"     // <runtime>/clip.changed
    readonly property string sessionStatus: runtime + "/session.json"   // <runtime>/session.json

    // State (07 §9), one per owner.
    readonly property string generatedLua: hyprState + "/generated.lua"    // ~/.local/state/aptus/hypr/generated.lua
    readonly property string bindsLocal: hyprState + "/binds.local.lua"      // ~/.local/state/aptus/hypr/binds.local.lua (Binds)
    readonly property string hyprlockConf: state + "/hyprlock.conf"    // ~/.local/state/aptus/hyprlock.conf
    readonly property string workspacesState: state + "/workspaces.json" // ~/.local/state/aptus/workspaces.json (Hypr, S3)
    readonly property string notificationsState: state + "/notifications.json" // ~/.local/state/aptus/notifications.json (S3)
    readonly property string frecencyState: state + "/frecency.json"   // ~/.local/state/aptus/frecency.json (S4)
    readonly property string clipboardDb: state + "/clipboard.db"     // ~/.local/state/aptus/clipboard.db (S4)
    readonly property string clipPins: state + "/clip-pins.json"        // ~/.local/state/aptus/clip-pins.json (S4)
    readonly property string focusState: state + "/focus.json"      // ~/.local/state/aptus/focus.json (S8)
    readonly property string focusLog: state + "/focus-log.jsonl"        // ~/.local/state/aptus/focus-log.jsonl (S8)
    readonly property string dndState: state + "/dnd.json"        // ~/.local/state/aptus/dnd.json (S8)
    readonly property string timersState: state + "/timers.json"     // ~/.local/state/aptus/timers.json (S8)
    readonly property string agendaFile: state + "/agenda.json"      // ~/.local/state/aptus/agenda.json (S8)
    readonly property string jotDraft: state + "/jot-draft.txt"        // ~/.local/state/aptus/jot-draft.txt (S8)
    readonly property string coloursState: state + "/colours.json"    // ~/.local/state/aptus/colours.json (S9)

    // Caches (07 §9), may be deleted at any time.
    readonly property string notifCache: cache + "/notif"      // ~/.cache/aptus/notif (S3)
    readonly property string clipCache: cache + "/clip"       // ~/.cache/aptus/clip (S4)
    readonly property string wallThumbs: cache + "/wall-thumbs"      // ~/.cache/aptus/wall-thumbs (S10)
    readonly property string weatherCache: cache + "/weather.json"    // ~/.cache/aptus/weather.json (S8)

    // Repo data.
    readonly property string knownBinds: shellDir + "/config/known-binds.json"      // <repo>/shell/config/known-binds.json (S8)
    readonly property string emojiFile: assets + "/emoji.json"       // <repo>/shell/assets/emoji.json (S4)
    readonly property string sounds: assets + "/sounds"          // <repo>/shell/assets/sounds (S3, S8)
    readonly property string fonts: assets + "/fonts"           // <repo>/shell/assets/fonts

    // "~/x" → "<home>/x"; other paths unchanged (config.js, the same rule settings use).
    function expand(path: string): string { return ConfigLib.expand(path, home); }
    // Whether a path (after expand) is inside HOME (the schema's insideHome rule, config.js).
    function insideHome(path: string): bool { return home !== "" && ConfigLib.insideHome(path, home); }
    // "file://" URL for Image sources and FileView paths.
    function url(path: string): string {
        if (path === "") return "";
        return "file://" + expand(path).split("/").map(encodeURIComponent).join("/");
    }
}
