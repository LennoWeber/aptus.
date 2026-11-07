pragma Singleton
// The only code that opens or closes anything (07-architecture §5). Holds one MonitorState per
// monitor plus the session-wide state, enforces the transition rules, and exposes the API that
// shortcuts, IPC and surfaces call.
import QtQuick
import Quickshell

Singleton {
    id: root

    // Hyprland monitor name → MonitorState.
    property var monitors: ({})
    // The focused monitor (from Hypr, wired by shell.qml); notch modes, Deck, toasts open here.
    property string activeMonitor: ""
    // The focused window's address (from Hypr, wired by shell.qml).
    property string currentWindow: ""
    // Session lock (from Session, wired by shell.qml).
    property bool locked: false
    // The monitor showing the polkit prompt ("" when none); other opens queue behind it.
    property string polkitMonitor: ""
    // Requests that arrived while polkit was open: [{ op, surface, args, monitor }].
    property var pending: []
    // The window that had focus before the current interactive surface opened (address), for
    // paste-back and the away catcher's focus replay.
    property string previousWindow: ""
    // The settings window (one per session, not per monitor).
    property bool settingsOpen: false
    property var settingsArgs: ({})
    // "monitor|surface" → function(): bool, registered by open surfaces for the Esc ladder.
    property var backHandlers: ({})
    // Source of passive entry ids.
    property int passiveSerial: 0

    signal surfaceOpened(string monitor, string surface)
    signal surfaceClosed(string monitor, string surface)
    // Asks the settings window to focus itself (open but not focused, settings.md §2).
    signal settingsFocusRequested()
}
