// IconButton: Icon-only button (03 §9): 28 (bar) or 32 (drawers), glyph 18, tooltip required.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): Glyph in a square with Wash and Tooltip (every icon-only control has one).

    property string glyph: ""
    property string tooltip: ""
    // Disabled with a reason: faint, no wash, but hover stays so the tooltip says why (03 §8);
    // use this instead of `enabled: false`, which also turns off hover.
    property string disabledReason: ""
    // "bar" | "drawer"
    property string size: "drawer"
    property bool on: false
    property bool keyboardFocus: false
    signal clicked()
    signal rightClicked()
    signal middleClicked()
}
