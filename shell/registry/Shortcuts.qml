// Every GlobalShortcut of 07-architecture §7 (appid "aptus"); Hyprland binds
// hl.dsp.global("aptus:<name>") (09-hyprland §7). Handlers route to SurfaceManager and services;
// the logic behind them lives there, so stages fill services without touching this file.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core
import qs.services

Scope {
    id: root

    // TODO(phase): Variants over `names` → GlobalShortcut { appid: "aptus"; name } with onPressed /
    //   onReleased → pressed()/released() (P-01: a Repeater needs an Item parent, Variants does not).
    // TODO(phase): routing table of 07 §7: surfaces → SurfaceManager.toggle; super-tap ends a peek or
    //   toggles Spotlight; keys-peek opens keysPeek (spotlight.superHoldKeys); the rest → service methods.

    // The names, in the order of 07 §7.
    readonly property var names: [
        "spotlight", "spotlight-clipboard", "spotlight-emoji",
        "super-tap", "keys-peek",
        "overview", "overview-open", "overview-close",
        "switcher-next", "switcher-prev", "switcher-commit",
        "deck", "today", "jot", "keys", "gallery", "session", "settings",
        "lock", "logout",
        "theme-toggle",
        "focus", "dnd", "quiet-bar",
        "capture-region", "capture-screen", "record", "colour",
        "vol-up", "vol-down", "vol-up-fine", "vol-down-fine", "mute", "mic-mute",
        "bright-up", "bright-down", "bright-up-fine", "bright-down-fine",
        "kbd-up", "kbd-down", "kbd-toggle",
        "media-toggle", "media-next", "media-prev"
    ]

    // A shortcut fired (the bind's key went down; for `release` binds, up).
    function pressed(name: string): void { throw new Error("Shortcuts.pressed: not implemented"); }
    // The key of a held shortcut went up (keys-peek ends the peek).
    function released(name: string): void { throw new Error("Shortcuts.released: not implemented"); }
}
