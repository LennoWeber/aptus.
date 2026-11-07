// Slider: Slider (03 §9): 4 px track, accent fill, 16 px thumb; leading glyph by level; value label (M-19).
import QtQuick
import qs.core

Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.05
    // Leading glyph; with `levelGlyphs` the glyph follows the value (volume: 0/33/66/100).
    property string glyph: ""
    property var levelGlyphs: []
    property string valueText: ""
    property string accessibleName: ""
    property bool keyboardFocus: false
    readonly property bool dragging: false
    signal moved(real value)
}
