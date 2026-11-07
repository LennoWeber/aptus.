// Base type of the docked drawers that are not notch modes (Deck, Overview).
import QtQuick

Item {
    // TODO(phase): content choreography (04 §3 rule 1) as in NotchMode, driven by `open`.

    property string monitorName: ""
    property bool open: false
    property var args: ({})
    property bool takesKeyboard: true
    property var keys: []

    // This drawer's part of the frame shape.
    readonly property BulgeSpec bulge: BulgeSpec {}

    signal closeRequested()

    // Esc ladder (05 §3) for levels inside the drawer other than Deck pages (SurfaceManager pops
    // MonitorState.deckPages itself). True when it stepped back internally.
    function back(): bool { return false; }
}
