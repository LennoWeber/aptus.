// Geometry of one drawer's bulge, published by the drawer and drawn by Frame as part of the one
// frame shape (03-visual-language §6.2). All values in monitor-local logical pixels.
import QtQuick

QtObject {
    // Whether the bulge is part of the frame shape now (also while it animates closed).
    property bool shown: false
    // "top" (hangs from the bar, coves on both sides), "topRight" / "topLeft" (docked into that
    // corner: cove at the bar and at the side edge), "topFull" (the whole lower edge of the bar
    // drops, as in the overview).
    property string dock: "top"
    // Left edge of the body and its size below the bar's bottom edge.
    property real x: 0
    property real width: 0
    property real height: 0
    // Concave radius where the body meets the frame; animates 0 → Tokens.cove while opening.
    property real cove: 0
    // Convex radius of the free corners.
    property real radius: 0
    // Cast the drawer shadow (only drawers that open over windows).
    property bool shadow: true
}
