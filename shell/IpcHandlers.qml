import QtQuick
import Quickshell
import Quickshell.Io
import qs.models

// IPC entry for the Hyprland binds. `aptus msg <command> [args]` (called by shell-switch) turns the kebab-case
// command into a call here: `aptus msg panel-toggle launcher` -> `qs -c aptus ipc call aptus panelToggle launcher`.
// The vocabulary matches the commands the user's hyprland.lua already sends, so existing binds keep working.
// Signatures only. Bodies come in phase 7.
Scope {
    id: root

    property var launcherState  // LauncherState
    property var shellState     // ShellState
    property var captureState   // CaptureState
    property var controlCenter  // ControlCenter
    property var audioState     // AudioState
    property var displayState   // DisplayState
    property var osd            // Osd

    // The launcher and the control center never show together.
    function openControlCenter(): void {
        launcherState.hide()
        shellState.openControlCenter()
    }

    function openNotifications(): void {
        launcherState.hide()
        openControlCenter()
        controlCenter.openTileById(Enums.TileId.Notifications)
    }

    IpcHandler {
        target: "aptus"

        // panel-toggle / panel-open: launcher, control-center, notification-center, wallpaper, session (power menu), design (unused).
        function panelToggle(name: string): void {
            if (["launcher", "control-center", "notification-center", "wallpaper", "session", "design"].indexOf(name) < 0) throw new Error("invariant: IpcHandlers.panelToggle: unknown panel name")
            // TODO(phase 7, sections 5 and 6): 'wallpaper' -> picker; 'session' -> power menu.
            if (name === "launcher") root.launcherState.toggle(Enums.LauncherMode.Apps)
            else if (name === "control-center") {
                if (root.shellState.stage === Enums.Stage.ControlCenter || root.shellState.stage === Enums.Stage.Detail) root.shellState.closeAll()
                else root.openControlCenter()
            }
            else if (name === "notification-center") {
                if (root.shellState.stage === Enums.Stage.Detail && root.shellState.activeTile === Enums.TileId.Notifications) root.shellState.closeAll()
                else root.openNotifications()
            }
            else console.warn("aptus: panel '" + name + "' is not available yet")
        }

        function panelOpen(name: string, arg: string): void {
            if (["launcher", "control-center", "notification-center", "wallpaper", "session", "design"].indexOf(name) < 0) throw new Error("invariant: IpcHandlers.panelOpen: unknown panel name")
            // TODO(phase 7, sections 4 to 6): the other panels; arg is a launcher query such as '/emo' (ignored for now).
            if (name === "launcher") root.launcherState.show(Enums.LauncherMode.Apps)
            else if (name === "control-center") root.openControlCenter()
            else if (name === "notification-center") root.openNotifications()
            else console.warn("aptus: panel '" + name + "' is not available yet")
        }

        // aptus-only: launcher-open apps|web|settings|ai|clipboard
        function launcherOpen(modeName: string): void {
            if (["apps", "web", "settings", "ai", "clipboard"].indexOf(modeName) < 0) throw new Error("invariant: IpcHandlers.launcherOpen: unknown launcher mode name")
            // Same hotkey with the mode already open closes the launcher.
            const modes = { apps: Enums.LauncherMode.Apps, web: Enums.LauncherMode.Web, settings: Enums.LauncherMode.Settings, ai: Enums.LauncherMode.Ai, clipboard: Enums.LauncherMode.Clipboard }
            root.launcherState.toggle(modes[modeName])
        }

        function settingsToggle(): void {
            throw new Error("not implemented")
        }

        function sessionLock(): void {
            // TODO(phase 7): the user's `shell-switch msg session lock` falls back to hyprlock if this shell does not answer.
            throw new Error("not implemented")
        }

        function screenshotRegion(): void {
            root.captureState.screenshot("region")
        }

        function screenshotScreen(): void {
            root.captureState.screenshot("screen")
        }

        function screenshotWindow(): void {
            root.captureState.screenshot("window")
        }

        // Starts a full-screen recording, or stops the running one.
        function recordScreenToggle(): void {
            if (root.captureState.recording) root.captureState.stopRecording()
            else root.captureState.startRecording("screen")
        }

        // Starts a region recording, or stops the running one.
        function recordToggle(): void {
            if (root.captureState.recording) root.captureState.stopRecording()
            else root.captureState.startRecording("region")
        }

        // Hardware keys. The shell shows the OSD and does the change (instant feedback).
        function brightnessUp(): void {
            root.displayState.changeBrightness(0.05)
            root.osd.flash(Enums.OsdKind.Brightness, root.displayState.brightness, false, "")
        }
        function brightnessDown(): void {
            root.displayState.changeBrightness(-0.05)
            root.osd.flash(Enums.OsdKind.Brightness, root.displayState.brightness, false, "")
        }
        function volumeUp(): void {
            if (root.audioState.muted) root.audioState.setMuted(false)
            const v = Math.min(1, root.audioState.volume + 0.05)
            root.audioState.setVolume(v)
            root.osd.flash(Enums.OsdKind.Volume, v, false, "")
        }
        function volumeDown(): void {
            const v = Math.max(0, root.audioState.volume - 0.05)
            root.audioState.setVolume(v)
            root.osd.flash(Enums.OsdKind.Volume, v, root.audioState.muted, "")
        }
        function volumeMute(): void {
            const nowMuted = !root.audioState.muted
            root.audioState.setMuted(nowMuted)
            root.osd.flash(Enums.OsdKind.Volume, root.audioState.volume, nowMuted, "")
        }
        function micMute(): void {
            const nowMuted = !root.audioState.inputMuted
            root.audioState.toggleInputMute()
            root.osd.flash(Enums.OsdKind.Microphone, root.audioState.inputVolume, nowMuted, "")
        }
        function media(action: string): void {
            if (["prev", "next", "play-pause"].indexOf(action) < 0) throw new Error("invariant: IpcHandlers.media: unknown media action")
            Quickshell.execDetached(["playerctl", action === "prev" ? "previous" : action])
        }
        function keyboardBacklight(action: string): void {
            if (["up", "down", "toggle"].indexOf(action) < 0) throw new Error("invariant: IpcHandlers.keyboardBacklight: unknown keyboard backlight action")
            const device = "*kbd_backlight*"
            if (action === "toggle") {
                Quickshell.execDetached(["sh", "-c", 'if [ "$(brightnessctl -d "*kbd_backlight*" get)" = 0 ]; then brightnessctl -d "*kbd_backlight*" set 100%; else brightnessctl -d "*kbd_backlight*" set 0; fi'])
            } else {
                Quickshell.execDetached(["brightnessctl", "-d", device, "set", action === "up" ? "+1" : "1-"])
            }
        }
        function themeModeToggle(): void {
            // aptus has no manual dark mode (light with a night-light blend), so this command is answered and ignored.
        }
        function logLevelStatus(): string {
            // Used by shell-switch to test that the shell answers after the start.
            return "ok"
        }
    }
}
