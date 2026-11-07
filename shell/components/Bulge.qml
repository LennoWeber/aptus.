// Bulge: The frame path (03 §6.2): the screen-edge band with every open drawer's bulge cut into the content area's outline, as one Shape. With bodiesOnly it draws just the bulge bodies (for the drawer shadow).
import QtQuick
import QtQuick.Shapes
import qs.core

Shape {
    id: root

    // TODO(phase): ShapePath with PathSvg from bulge.js framePath / bodiesPath (fillRule OddEvenFill),
    //   re-evaluated when any BulgeSpec changes.

    // Monitor-local size of the area the frame surrounds.
    property real frameWidth: 0
    property real frameHeight: 0
    // Thickness of the left/right/bottom edges and of the top band (the bar).
    // (Not `top`: that is Item's FINAL anchor line.)
    property real edge: 0
    property real barHeight: 0
    // Radius of the content area's inner corners (03 §6.1: 18).
    property real innerRadius: 0
    // The bulges to cut in.
    property list<BulgeSpec> bulges
    // Draw only the bulge bodies (shadow source) instead of the frame band.
    property bool bodiesOnly: false
    property color colour

    // The 1 px frame line along the content area's outline (03 §6, Tokens.frameLine); 0 = none.
    property color lineColour: "transparent"
    property real lineWidth: 0

    // Private state.
    // The open bulges as plain objects for bulge.js (reading every field keeps the binding live).
    readonly property var _specs: ({})
    readonly property string _path: ""
}
