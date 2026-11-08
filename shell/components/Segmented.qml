// Segmented: Segmented control (03 §9): 28 high, sunken track, sliding raised indicator.
// Controlled: it emits selected(value) and the owner writes `value`.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core

Item {
    id: root

    // [{ value, label }]
    property var options: []
    property var value
    property bool keyboardFocus: false
    signal selected(var value)

    readonly property int _index: {
        for (let i = 0; i < options.length; i++) if (options[i].value === value) return i;
        return -1;
    }
    readonly property real _inset: Tokens.s1
    readonly property real _padH: Tokens.button.padH
    // Natural width of every segment; extra width is shared evenly.
    readonly property real _natural: {
        let w = 0;
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i) as Segment;
            if (it) w += it.natural;
        }
        return w;
    }
    readonly property real _extra: options.length > 0 ? Math.max(0, (width - 2 * _inset - _natural) / options.length) : 0
    readonly property Item _current: _index >= 0 && rep.count > _index ? rep.itemAt(_index) : null

    function _pick(i: int): void {
        if (i >= 0 && i < options.length && i !== _index) root.selected(options[i].value);
    }

    implicitHeight: Tokens.segmented.height
    implicitWidth: _natural + 2 * _inset
    Accessible.role: Accessible.PageTabList

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) root._pick(root._index - 1);
        else if (event.key === Qt.Key_Right) root._pick(root._index + 1);
        else return;
        event.accepted = true;
    }

    component Segment: Item {
        id: seg
        required property var modelData
        required property int index
        readonly property real natural: label.implicitWidth + 2 * root._padH
        width: natural + root._extra
        height: root.height - 2 * root._inset
        Accessible.role: Accessible.PageTab
        Accessible.name: String(modelData.label)
        Accessible.selected: index === root._index

        Wash {
            anchors.fill: parent
            radius: Tokens.segmented.radius - root._inset
            hovered: mouse.containsMouse && seg.index !== root._index
            pressed: mouse.pressed && seg.index !== root._index
        }
        Label {
            id: label
            anchors.centerIn: parent
            text: String(seg.modelData.label)
            type: "body"
            ink: seg.index === root._index ? "main" : "sec"
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root._pick(seg.index)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.segmented.radius
        color: Tokens.sunken
    }
    // The selected segment's raised indicator slides on the snappy spring.
    Rectangle {
        visible: root._current !== null
        x: root._current ? row.x + root._current.x : 0
        y: root._inset
        width: root._current ? root._current.width : 0
        height: root.height - 2 * root._inset
        radius: Tokens.segmented.radius - root._inset
        color: Tokens.raised

        Behavior on x {
            enabled: !Motion.reduced
            SpringAnimation { spring: Motion.snappySpring; damping: Motion.snappyDamping; mass: Motion.snappyMass; epsilon: Motion.snappyEpsilon }
        }
        Behavior on width {
            enabled: !Motion.reduced
            SpringAnimation { spring: Motion.snappySpring; damping: Motion.snappyDamping; mass: Motion.snappyMass; epsilon: Motion.snappyEpsilon }
        }
    }
    Row {
        id: row
        x: root._inset
        y: root._inset

        Repeater {
            id: rep
            model: root.options
            delegate: Segment {}
        }
    }
    FocusRing {
        target: root
        targetRadius: Tokens.segmented.radius
        shown: root.keyboardFocus
    }
}
