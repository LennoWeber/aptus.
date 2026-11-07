// Tile: Toggle tile (03 §9): 88 × 64, glyph, label, state line, chevron area for its page.
import QtQuick
import qs.core

Item {
    id: root

    property string glyph: ""
    property string label: ""
    property string stateText: ""
    property bool on: false
    property bool hasPage: false
    property bool enabled: true
    property string disabledReason: ""
    property bool keyboardFocus: false
    signal toggled()
    signal pageRequested()
}
