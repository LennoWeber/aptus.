// The surface state of one monitor (07-architecture §5). Only SurfaceManager writes it;
// surfaces read it. One instance per Hyprland monitor name.
import QtQuick
import "js/rules.js" as Rules

QtObject {
    id: root
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
    // [{ id: int, kind: "toast" | "osd" | "event", key: string, payload: var, priority: int, born: ms,
    //   waited: bool }] (rules.js: waited = queued behind a blocking surface).
    // `key` replaces an entry of the same key (one OSD per kind, a notification's replaces_id).
    // Payload conventions: toast: a notification toast (services/js/notifications.js) or
    // { card: "capture" | "colour" | "stillOpen", …card fields, flyFrom: {x,y,width,height} (M-23) };
    // osd: services/js/levels.js; event { text, glyph }.
    property var passive: []
    // The arbitration result of notch.md §9: { kind: "osd" | "toast" | "event" | "card" | "rest" |
    // "hidden", entry } (entry: a passive entry, or for "card" the pinned activity id).
    property var passiveTop: ({ kind: "rest", entry: null })

    // The Deck and its page stack, owned by SurfaceManager: open("deck", { page }) pushes, back() pops (["main"] or ["main", "wifi"], …).
    property bool deck: false
    property var deckPages: ["main"]
    property var deckArgs: ({})

    property bool overview: false
    property var overviewArgs: ({})

    // An open menu: { anchorX, anchorY, model: [rows], owner: string, onTriggered: function(row) } in
    // monitor coordinates. MenuHost closes the menu, then calls onTriggered(row). An owner that
    // toggles its own menu checks `menu.owner` on press (the outside press reaches it first).
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

    // Derived: an interactive surface is open (away catcher, toasts queue). Cards and keysPeek are
    // not interactive (07 §5). Derived properties bind to Rules.interactive/keyboard/top(root).
    readonly property bool interactive: Rules.interactive(root)
    // Derived: the shell layer takes the keyboard (interactive, or a card opened by click).
    readonly property bool keyboard: Rules.keyboard(root)
    // Derived: the open surface that Esc/back acts on first ("" when none).
    readonly property string top: Rules.top(root)
}
