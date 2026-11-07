// Button: Buttons (03 §9): primary (one per surface), plain, quiet, risk.
import QtQuick
import qs.core

Item {
    id: root

    property string text: ""
    // "primary" | "plain" | "quiet" | "risk"
    property string variant: "plain"
    property string glyph: ""
    property bool enabled: true
    property string tooltip: ""
    // Show the focus ring (set by the surface after keyboard navigation).
    property bool keyboardFocus: false
    signal clicked()
}
