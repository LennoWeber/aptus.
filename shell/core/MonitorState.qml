// The surface state of one monitor (07-architecture §5). Only SurfaceManager writes it;
// surfaces read it. One instance per Hyprland monitor name.
import QtQuick

QtObject {
    // Hyprland monitor name ("eDP-1", "DP-1", …).
    required property string name

    // The notch mode: "rest" | "spotlight" | "switcher" | "today" | "session" | "polkit"
    // | "gallery" | "jot" | "keys" | "keysPeek" | "focusPicker" | "card:<activity>".
    property string notch: "rest"
    // Arguments of the last open() of the current notch mode (scope, query, page, …).
    property var notchArgs: ({})
    // Bumped by every open() of a notch mode, also when the mode stays the same.
    property int notchSerial: 0

    // Passive content waiting for or shown by the notch:
    // [{ id: int, kind: "toast" | "osd" | "event", payload: var, priority: int, born: ms }]
    property var passive: []
    // The arbitration result of notch.md §9 (one entry of `passive`), or null.
    property var passiveTop: null

    // The Deck and its page stack (["main"] or ["main", "wifi"], …).
    property bool deck: false
    property var deckPages: ["main"]
    property var deckArgs: ({})

    property bool overview: false
    property var overviewArgs: ({})

    // An open menu: { anchorX, anchorY, model: [rows], owner: string } in monitor coordinates.
    property var menu: null

    // Capture in progress: { mode: "region" | "screen" | "window" | "record" | "colour", args }.
    property var capture: null

    // A fullscreen window on this monitor's active workspace (from Hypr).
    property bool fullscreen: false

    // The surface that got the full ("hero") timeline in the last transition; the others use
    // their exit timeline without content choreography (04-motion §3 rule 8).
    property string hero: ""
    // True for one transition that must not animate (monitor removed, crash restore).
    property bool instant: false

    // Derived: an interactive surface is open (keyboard exclusive + away catcher).
    readonly property bool interactive: false
    // Derived: the open surface that Esc/back acts on first ("" when none).
    readonly property string top: ""
}
