// Bulge: The frame path (03 §6.2): the screen-edge band with every open drawer's bulge cut into the content area's outline, as one Shape. With bodiesOnly it draws just the bulge bodies (for the drawer shadow).
import QtQuick
import QtQuick.Shapes
import "../core/js/bulge.js" as B

Shape {
    id: root

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
    // The 1 px frame line along the content area's outline (03 §2 `line`, §6.1; Tokens.frameLine); 0 = none.
    property color lineColour: "transparent"
    property real lineWidth: 0

    width: frameWidth
    height: frameHeight
    preferredRendererType: Shape.CurveRenderer

    // The open bulges as plain objects for bulge.js (reading every field keeps the binding live).
    readonly property var _specs: {
        const out = [];
        for (let i = 0; i < bulges.length; i++) {
            const b = bulges[i];
            if (b && b.shown && (!bodiesOnly || b.shadow))
                out.push({ dock: b.dock, x: b.x, width: b.width, height: b.height, cove: b.cove, radius: b.radius });
        }
        return out;
    }
    readonly property string _path: bodiesOnly ? B.bodiesPath(frameWidth, edge, barHeight, _specs)
                                               : B.framePath(frameWidth, frameHeight, edge, barHeight, innerRadius, _specs)

    ShapePath {
        fillColor: root.colour
        fillRule: ShapePath.OddEvenFill
        strokeColor: root.lineWidth > 0 ? root.lineColour : "transparent"
        strokeWidth: root.lineWidth > 0 ? root.lineWidth : -1
        PathSvg { path: root._path }
    }
}
