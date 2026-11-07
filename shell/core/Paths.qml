pragma Singleton
// Every path the shell uses (07-architecture §2). Resolved once from the environment;
// under APTUS_TEST=1 everything derives from HOME (the harness points HOME at a temp dir).
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool test: false
    readonly property bool dev: false
    readonly property string home: ""
    readonly property string configHome: ""      // $XDG_CONFIG_HOME
    readonly property string stateHome: ""       // $XDG_STATE_HOME
    readonly property string cacheHome: ""       // $XDG_CACHE_HOME
    readonly property string dataHome: ""        // $XDG_DATA_HOME

    readonly property string config: ""          // ~/.config/aptus
    readonly property string state: ""           // ~/.local/state/aptus
    readonly property string cache: ""           // ~/.cache/aptus
    readonly property string runtime: ""         // $XDG_RUNTIME_DIR/aptus ($HOME/.aptus-run/aptus in tests)

    readonly property string shellDir: ""        // <repo>/shell
    readonly property string repo: ""            // <repo>
    readonly property string bin: ""             // <repo>/bin
    readonly property string tokensFile: ""      // <repo>/theme/tokens.json
    readonly property string schemaFile: ""      // <repo>/shell/config/settings-schema.json
    readonly property string assets: ""          // <repo>/shell/assets

    readonly property string settingsFile: ""    // ~/.config/aptus/settings.json
    readonly property string calendarsFile: ""   // ~/.config/aptus/calendars.json
    readonly property string wallpaperState: ""  // ~/.local/state/aptus/wallpaper.json
    readonly property string uiState: ""         // ~/.local/state/aptus/ui.json
    readonly property string lockedMarker: ""    // ~/.local/state/aptus/locked
    readonly property string leaseJournal: ""    // ~/.local/state/aptus/lease/journal.json
    readonly property string themeCurrent: ""    // ~/.local/state/aptus/theme/current
    readonly property string hyprState: ""       // ~/.local/state/aptus/hypr
    readonly property string restartFlag: ""     // <runtime>/restart
    readonly property string introFlag: ""       // <runtime>/intro.<HYPRLAND_INSTANCE_SIGNATURE>
    readonly property string guardState: ""      // <runtime>/guard.state
    readonly property string clipChanged: ""     // <runtime>/clip.changed
    readonly property string sessionStatus: ""   // <runtime>/session.json

    // State (07 §9), one per owner.
    readonly property string generatedLua: ""    // ~/.local/state/aptus/hypr/generated.lua
    readonly property string bindsLocal: ""      // ~/.local/state/aptus/hypr/binds.local.lua (Binds)
    readonly property string hyprlockConf: ""    // ~/.local/state/aptus/hyprlock.conf
    readonly property string workspacesState: "" // ~/.local/state/aptus/workspaces.json (Hypr, S3)
    readonly property string notificationsState: "" // ~/.local/state/aptus/notifications.json (S3)
    readonly property string frecencyState: ""   // ~/.local/state/aptus/frecency.json (S4)
    readonly property string clipboardDb: ""     // ~/.local/state/aptus/clipboard.db (S4)
    readonly property string clipPins: ""        // ~/.local/state/aptus/clip-pins.json (S4)
    readonly property string focusState: ""      // ~/.local/state/aptus/focus.json (S8)
    readonly property string focusLog: ""        // ~/.local/state/aptus/focus-log.jsonl (S8)
    readonly property string dndState: ""        // ~/.local/state/aptus/dnd.json (S8)
    readonly property string timersState: ""     // ~/.local/state/aptus/timers.json (S8)
    readonly property string agendaFile: ""      // ~/.local/state/aptus/agenda.json (S8)
    readonly property string jotDraft: ""        // ~/.local/state/aptus/jot-draft.txt (S8)
    readonly property string coloursState: ""    // ~/.local/state/aptus/colours.json (S9)

    // Caches (07 §9), may be deleted at any time.
    readonly property string notifCache: ""      // ~/.cache/aptus/notif (S3)
    readonly property string clipCache: ""       // ~/.cache/aptus/clip (S4)
    readonly property string wallThumbs: ""      // ~/.cache/aptus/wall-thumbs (S10)
    readonly property string weatherCache: ""    // ~/.cache/aptus/weather.json (S8)

    // Repo data.
    readonly property string knownBinds: ""      // <repo>/shell/config/known-binds.json (S8)
    readonly property string emojiFile: ""       // <repo>/shell/assets/emoji.json (S4)
    readonly property string sounds: ""          // <repo>/shell/assets/sounds (S3, S8)
    readonly property string fonts: ""           // <repo>/shell/assets/fonts

    // "~/x" → "<home>/x"; other paths unchanged.
    function expand(path: string): string { throw new Error("Paths.expand: not implemented"); }
    // Whether a path (after expand) is inside HOME (the insideHome rule of the schema).
    function insideHome(path: string): bool { throw new Error("Paths.insideHome: not implemented"); }
    // "file://" URL for Image sources and FileView paths.
    function url(path: string): string { throw new Error("Paths.url: not implemented"); }
    // Create a directory and its parents (Process `mkdir -p`); fire and forget.
    function ensureDir(path: string): void { throw new Error("Paths.ensureDir: not implemented"); }
}
