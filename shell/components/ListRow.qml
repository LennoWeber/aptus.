// ListRow: List row (03 §9): 36 high (44 in Spotlight), leading icon, title, trailing meta or keycaps; current = wash.
// Pointer: hover washes (current + hover = currentHover), click activates, right click asks for the
// context menu at the pointer in window (= monitor-local) coordinates. Inside a List the moving
// highlight draws the current wash, so the row only adds it under the pointer.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core

Item {
    id: root

    property string glyph: ""
    // App icon name instead of a glyph.
    property string icon: ""
    property string iconFallback: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property var keycaps: []
    property bool current: false
    property bool large: false
    property bool strong: true
    signal activated()
    signal contextRequested(real x, real y)

    readonly property bool _app: icon !== "" || (glyph === "" && iconFallback !== "")
    readonly property bool _hasLead: glyph !== "" || _app
    readonly property real _leadSize: _app ? (large ? Tokens.appIconSpotlight : Tokens.appIconRow)
                                           : (large ? Tokens.glyphHeader : Tokens.glyphRow)
    // A ListView delegate whose view draws a highlight (List) leaves the current wash to it.
    readonly property bool _viewHighlights: ListView.view !== null && ListView.view.highlightItem !== null

    implicitHeight: large ? Tokens.listRow.heightSpotlight : Tokens.listRow.height
    implicitWidth: Tokens.padRowH * 2 + (_hasLead ? _leadSize + Tokens.gapRowIcon : 0)
                   + Math.max(titleLabel.implicitWidth, subtitleLabel.visible ? subtitleLabel.implicitWidth : 0)
                   + (trail.width > 0 ? Tokens.s5 + trail.width : 0)
    Accessible.role: Accessible.ListItem
    Accessible.name: title
    Accessible.description: subtitle
    Accessible.selected: current
    Accessible.onPressAction: root.activated()

    Wash {
        anchors.fill: parent
        radius: Tokens.listRow.radius
        hovered: mouse.containsMouse && root.enabled
        current: root.current && (!root._viewHighlights || mouse.containsMouse)
        pressed: mouse.pressed && mouse.pressedButtons === Qt.LeftButton
    }
    Item {
        id: lead
        x: Tokens.padRowH
        anchors.verticalCenter: parent.verticalCenter
        width: root._hasLead ? root._leadSize : 0
        height: width
        visible: root._hasLead

        Glyph {
            anchors.centerIn: parent
            visible: !root._app
            name: root.glyph
            size: root._leadSize
            // 03 §8: a selected row's glyph turns FILL 1
            on: root.current
            colour: root.enabled ? (root.current ? Tokens.inkMain : Tokens.inkSec) : Tokens.inkFaint
        }
        Loader {
            anchors.fill: parent
            active: root._app
            sourceComponent: AppIcon {
                icon: root.icon
                name: root.iconFallback !== "" ? root.iconFallback : root.title
                size: root._leadSize
            }
        }
    }
    Column {
        anchors.left: lead.visible ? lead.right : parent.left
        anchors.leftMargin: lead.visible ? Tokens.gapRowIcon : Tokens.padRowH
        anchors.right: trail.left
        anchors.rightMargin: trail.width > 0 ? Tokens.s5 : 0
        anchors.verticalCenter: parent.verticalCenter

        Label {
            id: titleLabel
            width: parent.width
            text: root.title
            type: root.strong ? "bodyStrong" : "body"
            ink: root.enabled ? "main" : "faint"
        }
        Label {
            id: subtitleLabel
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            type: "micro"
            ink: root.enabled ? "meta" : "faint"
        }
    }
    Row {
        id: trail
        anchors.right: parent.right
        anchors.rightMargin: Tokens.padRowH
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.s2

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.trailing !== ""
            text: root.trailing
            ink: root.enabled ? "meta" : "faint"
            elide: Text.ElideNone
        }
        Repeater {
            model: root.keycaps
            delegate: Keycap {
                required property var modelData
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                text: String(modelData)
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) {
                const p = root.mapToItem(null, event.x, event.y);
                root.contextRequested(p.x, p.y);
            } else {
                root.activated();
            }
        }
    }
}
