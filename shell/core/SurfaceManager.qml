pragma Singleton
// The only code that opens or closes anything (07-architecture §5). Holds one MonitorState per
// monitor plus the session-wide state, enforces the transition rules, and exposes the API that
// shortcuts, IPC and surfaces call.
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): MonitorState objects created with Component.createObject per Hypr monitor (syncMonitors).
    // TODO(phase): every API function = snapshot → rules.js → _apply; a Timer runs rules.expire while
    //   passive content waits (events 4 s, toasts 30 s).
    // TODO(phase): react to activeMonitor (close notch modes on the old one) and locked (07 §5);
    //   both are bindings from shell.qml, never written here (rules.js tracks _lastActive).
    // TODO(phase): fullscreenMonitors → rules.setFullscreen per changed monitor; a 500 ms Timer runs
    //   rules.tick while _hasPassive (events age out without an operation).
    // TODO(phase): limits ← Tokens.surfaces (toast.staleMs, event.maxAgeMs, notch.pinnedCardTimeoutMs);
    //   optional parameters normalised (undefined/"" monitor → activeMonitor, args → {}, key → "").

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
    // The settings window has keyboard focus (toggle semantics of settings.md §2).
    property bool settingsFocused: false
    // Timing limits for rules.js, from Tokens (toast.staleMs, event.maxAgeMs).
    readonly property var limits: ({})
    // "monitor|surface" → function(): bool, registered by open surfaces for the Esc ladder.
    property var backHandlers: ({})
    // Source of passive entry ids.
    property int passiveSerial: 0

    signal surfaceOpened(string monitor, string surface)
    signal surfaceClosed(string monitor, string surface)
    // Asks the settings window to focus itself (open but not focused, settings.md §2).
    signal settingsFocusRequested()

    // ── API (07 §5; also over IPC). Optional parameters are `var` and may be omitted: an
    // omitted typed string parameter would arrive as "undefined" (Qt 6.11, phase-3 probe).
    // `monitor` omitted or "" means the active monitor; `args` omitted means {}. ─────────────
    // Open a surface: a notch mode id, "card:<activity>", "deck", "overview", "capture",
    // "settings". Returns false when refused (locked) or queued (polkit open).
    function open(surface: string, args: var, monitor: var): bool { throw new Error("SurfaceManager.open: not implemented"); }
    function close(surface: string, monitor: var): void { throw new Error("SurfaceManager.close: not implemented"); }
    // Its own key again closes it (05 §3 way out 3); the settings window is focused when open but
    // not focused (settings.md §2).
    function toggle(surface: string, args: var, monitor: var): bool { throw new Error("SurfaceManager.toggle: not implemented"); }
    // The Esc ladder (05 §3): the menu, then the top surface's back handler, then the surface.
    function back(monitor: var): void { throw new Error("SurfaceManager.back: not implemented"); }
    // Passive content for the notch: kind "toast" | "osd" | "event". A non-empty key replaces the
    // entry with the same key in place (one OSD per kind, replaces_id). Returns the entry id.
    // priority defaults to 0 (critical toasts pass 2, as notification urgency).
    function post(kind: string, payload: var, priority: var, monitor: var, key: var): int { throw new Error("SurfaceManager.post: not implemented"); }
    // Change a passive entry's payload in place (stack toast growing, OSD value change).
    function update(id: int, payload: var, monitor: var): void { throw new Error("SurfaceManager.update: not implemented"); }
    // Remove a passive entry (toast timed out or dismissed, OSD faded).
    function dismiss(id: int, monitor: var): void { throw new Error("SurfaceManager.dismiss: not implemented"); }
    // JSON of every MonitorState and the session-wide state (IPC `shell state`, tests).
    function state(): string { throw new Error("SurfaceManager.state: not implemented"); }
    function isOpen(surface: string, monitor: var): bool { throw new Error("SurfaceManager.isOpen: not implemented"); }
    function monitorState(name: string): MonitorState { throw new Error("SurfaceManager.monitorState: not implemented"); }

    // Menus (03 §9): one per monitor, above every surface, closed first by Esc.
    function openMenu(monitor: string, menu: var): void { throw new Error("SurfaceManager.openMenu: not implemented"); }
    function closeMenu(monitor: string): void { throw new Error("SurfaceManager.closeMenu: not implemented"); }

    // Open surfaces register a back step: fn() returns true when it went back internally.
    function registerBack(monitor: string, surface: string, fn: var): void { throw new Error("SurfaceManager.registerBack: not implemented"); }
    function unregisterBack(monitor: string, surface: string): void { throw new Error("SurfaceManager.unregisterBack: not implemented"); }

    // The settings window reports its focus (toggle semantics of settings.md §2).
    function setSettingsFocused(focused: bool): void { throw new Error("SurfaceManager.setSettingsFocused: not implemented"); }

    // ── Internal ──────────────────────────────────────────────────────────────────────────
    // Keep `monitors` in step with Hypr.monitors (create, remove without animation).
    function syncMonitors(names: var): void { throw new Error("SurfaceManager.syncMonitors: not implemented"); }
    // Copy a rules.js result into the MonitorState objects and emit the signals of its effects.
    function _apply(result: var): void { throw new Error("SurfaceManager._apply: not implemented"); }
    // Plain-object snapshot of the current state for rules.js.
    function _snapshot(): var { throw new Error("SurfaceManager._snapshot: not implemented"); }
    function _monitorFor(monitor: var): string { throw new Error("SurfaceManager._monitorFor: not implemented"); }

    // Hyprland monitor names with a fullscreen window on their active workspace (bound from
    // Hypr.fullscreenMonitors in shell.qml; applied through rules.setFullscreen, M-31).
    property var fullscreenMonitors: []

    // Private state.
    // The active monitor as rules.js last saw it (the Spotlight rule needs the old one).
    property string _lastActive: ""
    // The MonitorState fields copied from a rules.js result, in order (_apply).
    readonly property var _fields: []
    // Any monitor has passive content (runs the expiry tick only then).
    readonly property bool _hasPassive: false

    // Private helpers.
    // Tell rules.js about a new active monitor (setActive) when it differs from _lastActive.
    function _syncActive(): void { throw new Error("SurfaceManager._syncActive: not implemented"); }
}
