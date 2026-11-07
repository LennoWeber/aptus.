// Slider: Slider (03 §9): 4 px track, accent fill, 16 px thumb; leading glyph by level; value label (M-19).
import QtQuick
import qs.core

Item {
    id: root
    // TODO(phase): controlled: never writes `value`; shows its own value only while dragging. Keys ← →
    //   only (↑ ↓ move between Deck rows); a click on the leading glyph emits glyphClicked().

    // TODO(phase): track, fill, thumb, level glyphs, drag + wheel + keyboard; emits moved().

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
    // A click on the leading glyph (deck.md §4: click = mute).
    signal glyphClicked()

    // Private state.
    property bool _dragging: false
    property real _dragValue: 0
    property real _pressX: 0
    readonly property real _shown: 0
    readonly property real _fraction: 0
    // Index into levelGlyphs: 0 at the bottom of the range, then one per Tokens.slider.volumeSteps
    // interval (0, (0,33], (33,66], (66,100]); other lengths spread evenly.
    readonly property int _level: 0
    readonly property string _glyph: ""

    // Private helpers.
    function _clamp(v: real): real { throw new Error("Slider._clamp: not implemented"); }
    function _snap(v: real): real { throw new Error("Slider._snap: not implemented"); }
    function _valueAt(px: real): real { throw new Error("Slider._valueAt: not implemented"); }
}
