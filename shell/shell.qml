// aptus v2 shell root (07-architecture §2–§4): `qs -p <repo>/shell`.
// TODO(phase): `//@ pragma UseQApplication` + ShellRoot with settings.watchFiles from APTUS_DEV
//   (probe P-23: file watching off in normal runs).
// TODO(phase): Bindings into core (module order: core never imports services): Tokens.wallpaperHue/
//   wallpaperLightness/wallpaperChroma ← Wallpaper; SurfaceManager.activeMonitor/currentWindow/locked ← Hypr/Session.
// TODO(phase): SurfaceManager.syncMonitors(Hypr.monitors) on every monitor change;
//   SurfaceManager.fullscreenMonitors ← Hypr.fullscreenMonitors (M-31).
// TODO(phase): Variants over Quickshell.screens → MonitorShell { notchModes: NotchModes.components;
//   activities: Activities.activities; cards: Activities.cards }.
// TODO(phase): one Shortcuts {} and one Ipc {}; Lock {}; a Loader for SettingsWindow while
//   SurfaceManager.settingsOpen.
// TODO(phase): start order of 07 §3 step 2: every MonitorShell's layers start hidden until Config
//   and Tokens have resolved (no unstyled first frame).
// TODO(phase): step 3: touch Hypr, Notifications (owns the bus name before apps send), Idle, Session
//   and Wallpaper in Component.onCompleted (singletons are lazy); Shortcuts and Ipc are objects here.
// TODO(phase): steps 4–5: locked marker → lock at once without intro; intro flag for this Hyprland
//   signature missing → introProgress 0 → 1 (M-01), then write the flag.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.services
import qs.registry
import qs.windows
import qs.surfaces.lock
import qs.surfaces.settings

ShellRoot {
    id: root

    // 0 → 1 during the session intro (M-01); every MonitorShell's introProgress.
    property real introProgress: 1
    // The start check (locked marker, intro flag; 07 §3 steps 4–5) has answered.
    property bool _startChecked: false
    // Config and Tokens have resolved and the start check answered: the MonitorShells appear
    // (07 §3 step 2, no unstyled first frame).
    readonly property bool _ready: false
}
