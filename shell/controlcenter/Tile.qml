import QtQuick
import qs.models
import qs.theme
import qs.components

// Frame around one tile.
Rectangle {
    id: tile

    property int tileId  // Enums.TileId
    property string title
    property bool expanded
    property int severity  // Enums.Severity
    property var spec  // tile layout entry
    property bool active   // switched on: the tile fills with ink (caffeine, focus)
    property bool hasDetail: true   // shows the open arrow on hover
    property int order      // position in the grid, staggers the entrance
    property bool shown     // the control center is open
    default property alias content: contentArea.data
    signal activated(int tileId)

    // Entrance: 0 = just below and small, 1 = in place. Replays every time the control center opens.
    property real appear: 1
    onShownChanged: {
        if (shown) { appear = 0; enter.restart() }
        else enter.stop()
    }
    SequentialAnimation {
        id: enter
        PauseAnimation { duration: Math.min(tile.order, 12) * Tokens.staggerMs }
        NumberAnimation { target: tile; property: "appear"; to: 1; duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] }
    }

    // TODO(phase 7, Bild-Theming): with a style the fill is one of Tokens.wash1..wash4 by tile position (for example (column + row) % 4); Standard keeps surface.
    color: active ? Tokens.ink : Tokens.surface
    Behavior on color { ColorAnimation { duration: Tokens.durFast } }
    radius: Tokens.radiusTile
    border.width: 1
    border.color: active ? Tokens.ink : Qt.tint(Tokens.line, Qt.rgba(Tokens.inkFaint.r, Tokens.inkFaint.g, Tokens.inkFaint.b, hover))

    // Hover: the tile lifts, its edge darkens a little and the shadow deepens. Never a colour.
    property real hover: area.pressed ? 0.6 : area.containsMouse ? 1 : 0
    Behavior on hover { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    transform: [
        Translate { y: -Tokens.tileLift * tile.hover + 14 * (1 - tile.appear) },
        Scale {
            origin.x: tile.width / 2
            origin.y: tile.height / 2
            xScale: (0.96 + 0.04 * tile.appear) * (1 - 0.008 * (area.pressed ? 1 : 0))
            yScale: xScale
        }
    ]

    Rectangle {
        z: -1
        anchors.fill: parent
        anchors.topMargin: 4 + 3 * tile.hover
        anchors.bottomMargin: -4 - 3 * tile.hover
        anchors.leftMargin: 3
        anchors.rightMargin: 3
        radius: tile.radius
        color: Tokens.ink
        opacity: 0.03 + 0.08 * tile.hover
    }

    // Soft tint over the surface (lighter on an ink tile).
    Rectangle {
        anchors.fill: parent
        radius: tile.radius
        color: tile.active ? Tokens.bg : Tokens.surfaceAlt
        opacity: (tile.active ? 0.10 : 0.8) * tile.hover
    }

    // Behind the content: controls inside the tile take their own clicks first.
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: tile.activated(tile.tileId)
    }

    Label {
        x: 16
        y: 13
        text: tile.title
        role: Enums.TextRole.Bar
        tone: tile.severity
        color: tile.active ? Qt.rgba(Tokens.bg.r, Tokens.bg.g, Tokens.bg.b, 0.7)
            : tile.severity === Enums.Severity.Neutral ? Tokens.inkFaint : Tokens.colorFor(tile.severity)
    }

    // Open arrow, top right: appears on hover and slides in a little. The whole tile opens the detail view as well.
    Item {
        id: openArrow
        visible: tile.hasDetail
        width: 28
        height: 28
        x: parent.width - width - 10
        y: 8
        opacity: tile.hover
        transform: Translate { x: -4 * (1 - tile.hover); y: 4 * (1 - tile.hover) }
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: arrowArea.containsMouse ? Tokens.ink : Tokens.surface
            border.width: 1
            border.color: arrowArea.containsMouse ? Tokens.ink : Tokens.line
            Behavior on color { ColorAnimation { duration: Tokens.durFast } }
        }
        StatusGlyph {
            anchors.centerIn: parent
            width: 14
            height: 14
            kind: "open"
            color: arrowArea.containsMouse ? Tokens.bg : Tokens.inkSoft
        }
        MouseArea {
            id: arrowArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.activated(tile.tileId)
        }
    }

    Item {
        id: contentArea
        anchors { fill: parent; leftMargin: 16; rightMargin: 16; bottomMargin: 14; topMargin: 38 }
    }
}
