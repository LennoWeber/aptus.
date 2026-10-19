pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Idle policy: lock first, then screen off. NEVER sleep. Replaces the user's hypridle only while aptus runs
// (the user's hypridle.conf stays as a safety net when another shell is active).
// Signatures only. Bodies come in phase 7.
Singleton {
    // Caffeine (manual) or a fullscreen window keeps the screen awake.
    property bool inhibit: caffeine || fullscreenInhibit
    property bool caffeine
    property bool fullscreenInhibit

    // Minutes from AppSettings (lockAfterMin / screenOffAfterMin).
    IdleMonitor {
        id: lockMonitor
        enabled: false
        respectInhibitors: true
        // TODO(phase 7): timeout = AppSettings.lockAfterMin * 60; on idle call Session.lockScreen().
    }

    IdleMonitor {
        id: screenOffMonitor
        enabled: false
        respectInhibitors: true
        // TODO(phase 7): timeout = AppSettings.screenOffAfterMin * 60; on idle `hyprctl dispatch dpms off`, back on at activity.
    }

    // Lid state, polled because Quickshell has no lid type. Used only for lock-on-lid-close.
    Process {
        id: lidProbe
        running: false
        // TODO(phase 7): primary way is a Hyprland switch bind (check the Lua API: bind on the 'Lid Switch' device);
        // TODO(phase 7): fallback is reading /proc/acpi/button/lid/*/state once per second (Process + Timer) while a lock-on-lid is wanted.
    }

    function configure(lockAfterMin: int, screenOffAfterMin: int): void {
        if (!Number.isInteger(lockAfterMin) || !Number.isInteger(screenOffAfterMin) || lockAfterMin < 0 || screenOffAfterMin < 0) throw new Error("invariant: Idle.configure: minutes must be integers >= 0 (0 = never)")
        if (screenOffAfterMin > 0 && (lockAfterMin === 0 || screenOffAfterMin <= lockAfterMin)) throw new Error("invariant: Idle.configure: screen off must come strictly after the lock, and never without a lock")
        // TODO(phase 7): set both monitor timeouts, enable them, never create a suspend or hibernate path.
        throw new Error("not implemented")
    }

    // Caffeine.
    function setCaffeine(on: bool): void {
        // `inhibit` follows by binding; the actual IdleInhibitor lives in the bar window (it needs a window): see Bar.qml.
        caffeine = on
    }

    function setFullscreenInhibit(on: bool): void {
        // Driven by the Hyprland fullscreen state when AppSettings.keepAwakeWhenFullscreen (wired in the idle section).
        fullscreenInhibit = on
    }

    // Lock only.
    function onLidClosed(): void {
        // TODO(phase 7): Session.lockScreen() only; logind already ignores the lid (50-hp-sleep.conf, checked by the installer).
        throw new Error("not implemented")
    }
}
