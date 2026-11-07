// Base type of a result card shown in the notch like a toast (a toast whose payload has
// `card: <id>`): the capture card, the colour card, the logout "still open" card. The Notch
// takes the component from the Activities registry's `cards` table.
import QtQuick

Item {
    // TODO(phase): cardHeight default ← Tokens.surfaces.notch.resultCardHeight, not 96.

    property string monitorName: ""
    // The toast payload (card-specific fields).
    property var payload: ({})
    // The pointer is over the card (its timer pauses, capture.md §3 step 4).
    property bool hovered: false
    // The bulge height this card wants (width is always the card width, 420).
    property real cardHeight: 96
    // The card is done (button pressed, Undo window over).
    signal closeRequested()
}
