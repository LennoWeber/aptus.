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

    // Private state.
    // Disabled with a reason: faint, no wash, the tooltip says why (03 §8); the page still opens.
    readonly property bool _disabled: false
    readonly property real _chevron: 0
    readonly property bool _overMain: false
    readonly property bool _overChevron: false
    // State line swap (M-18, 04 §3 rule 5 style): the old line rises and fades, the new one rises in.
    property string _oldState: ""
    property string _lastState: ""
    property real _swap: 1
}
