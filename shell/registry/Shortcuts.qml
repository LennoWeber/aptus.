// Every GlobalShortcut of 07-architecture §7 (appid "aptus"); Hyprland binds
// hl.dsp.global("aptus:<name>") (09-hyprland §7). Handlers route to SurfaceManager and services;
// the logic behind them lives there, so stages fill services without touching this file.
pragma ComponentBehavior: Bound
// qmllint disable import
// (GlobalShortcut's qmltypes lack their dependency on Quickshell's PostReloadHook; a packaging gap)
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core
import qs.services

Scope {
    id: root

    // The names, in the order of 07 §7 (the order of _routes below).
    readonly property var names: Object.keys(_routes)

    // Surfaces whose stage has not built them yet: their shortcuts only log, so an empty surface
    // never takes the keyboard with nothing on screen (IPC still opens them, for tests). Each stage
    // removes its own line.
    readonly property var notBuilt: [
        "spotlight",                            // S4
        "deck",                                 // S5
        "session",                              // S6
        "overview",                             // S7
        "today", "jot", "keys", "keysPeek",     // S8
        "gallery", "settings"                   // S10
    ]

    // A shortcut fired (the bind's key went down; for `release` binds, up).
    function pressed(name: string): void {
        Log.debug("shortcut", name);
        const fn = _routes[name];
        if (!fn) { Log.warn("shortcut", "no route for " + name); return; }
        try { fn(); } catch (e) { Log.error("shortcut", name + ": " + e); }
    }
    // The key of a held shortcut went up (keys-peek ends the peek).
    function released(name: string): void {
        if (name === "keys-peek" && _activeNotch() === "keysPeek") SurfaceManager.close("keysPeek");
    }

    // False (and a log line) for a surface in notBuilt.
    function _built(surface: string): bool {
        if (notBuilt.indexOf(surface) < 0) return true;
        Log.info("shortcut", surface + ": not available yet");
        return false;
    }
    // The notch mode open on the active monitor, "" none.
    function _activeNotch(): string {
        const m = SurfaceManager.monitorState(SurfaceManager.activeMonitor);
        return m ? m.notch : "";
    }
    // Spotlight in a scope: the same key again closes it, another scope switches (07 §7).
    function _spotlightScope(scope: string): void {
        const m = SurfaceManager.monitorState(SurfaceManager.activeMonitor);
        if (m && m.notch === "spotlight" && (m.notchArgs.scope || "") === scope) SurfaceManager.close("spotlight");
        else if (_built("spotlight")) SurfaceManager.open("spotlight", { scope: scope });
    }

    // name → action (07 §7); a new shortcut is one line here plus its bind in hypr/binds.lua.
    readonly property var _routes: ({
        "spotlight": () => _spotlightScope(""),
        "spotlight-clipboard": () => _spotlightScope("clipboard"),
        "spotlight-emoji": () => _spotlightScope("emoji"),
        // a release after a shown peek ends it and does not open Spotlight (keys-jot.md §1)
        "super-tap": () => {
            if (_activeNotch() === "keysPeek") SurfaceManager.close("keysPeek");
            else if (Config.get("spotlight.superTap")) _spotlightScope("");
        },
        "keys-peek": () => { if (Config.get("spotlight.superHoldKeys") && _built("keysPeek")) SurfaceManager.open("keysPeek", { peek: true }); },
        "overview": () => _built("overview") && SurfaceManager.toggle("overview"),
        "overview-open": () => _built("overview") && SurfaceManager.open("overview"),
        "overview-close": () => SurfaceManager.close("overview"),
        "switcher-next": () => Switcher.next(),
        "switcher-prev": () => Switcher.previous(),
        "switcher-commit": () => Switcher.commit(),
        "deck": () => _built("deck") && SurfaceManager.toggle("deck"),
        "today": () => _built("today") && SurfaceManager.toggle("today"),
        "jot": () => _built("jot") && SurfaceManager.toggle("jot"),
        "keys": () => _built("keys") && SurfaceManager.toggle("keys"),
        "gallery": () => _built("gallery") && SurfaceManager.toggle("gallery"),
        "session": () => _built("session") && SurfaceManager.toggle("session"),
        "settings": () => _built("settings") && SurfaceManager.toggle("settings"),
        "lock": () => Session.lock(),
        "logout": () => Session.logout(),
        "theme-toggle": () => Theme.toggleMode(),
        "focus": () => Focus.shortcut(),
        "dnd": () => Dnd.toggle(),
        "quiet-bar": () => Focus.toggleQuietBar(),
        "capture-region": () => Capture.region(),
        "capture-screen": () => Capture.screen(),
        "record": () => Capture.record(),
        "colour": () => Capture.colour(),
        "vol-up": () => Audio.stepVolume(1, false),
        "vol-down": () => Audio.stepVolume(-1, false),
        "vol-up-fine": () => Audio.stepVolume(1, true),
        "vol-down-fine": () => Audio.stepVolume(-1, true),
        "mute": () => Audio.toggleMute(),
        "mic-mute": () => Audio.toggleMicMute(),
        "bright-up": () => Brightness.step(1, false),
        "bright-down": () => Brightness.step(-1, false),
        "bright-up-fine": () => Brightness.step(1, true),
        "bright-down-fine": () => Brightness.step(-1, true),
        "kbd-up": () => Brightness.kbdStep(1),
        "kbd-down": () => Brightness.kbdStep(-1),
        "kbd-toggle": () => Brightness.kbdToggle(),
        "media-toggle": () => Media.toggle(),
        "media-next": () => Media.next(),
        "media-prev": () => Media.previous()
    })

    // qmllint disable import unresolved-type required
    // (the _GlobalShortcuts qmltypes do not declare their dependency on Quickshell's PostReloadHook)
    Variants {
        model: root.names
        GlobalShortcut {
            required property string modelData
            appid: "aptus"
            name: modelData
            description: modelData
            onPressed: root.pressed(modelData)
            onReleased: root.released(modelData)
        }
    }
    // qmllint enable import unresolved-type required
}
