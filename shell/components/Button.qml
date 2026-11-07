// Button: Buttons (03 §9): primary (one per surface), plain, quiet, risk.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): label + optional glyph, kinds plain/primary/risk, press scale 0.97 (M-xx press), Wash, FocusRing.

    property string text: ""
    // "primary" | "plain" | "quiet" | "risk"
    property string variant: "plain"
    property string glyph: ""
    property string tooltip: ""
    // Show the focus ring (set by the surface after keyboard navigation).
    property bool keyboardFocus: false
    signal clicked()
}
