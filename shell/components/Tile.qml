// Tile: Toggle tile (03 §9): 88 × 64, glyph, label, state line, chevron area for its page.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): the Deck tile of 03 §9: glyph, title, subtitle, on state in accentWash, chevron for pages.

    property string glyph: ""
    property string label: ""
    property string stateText: ""
    property bool on: false
    property bool hasPage: false
    property string disabledReason: ""
    property bool keyboardFocus: false
    signal toggled()
    signal pageRequested()
}
