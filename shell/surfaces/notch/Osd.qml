pragma ComponentBehavior: Bound
// The OSD (surfaces/notch.md §8, M-07): glyph 20 · level 180 × 6 (spring.snappy, the part over
// 100 in warn) · value (tabular, ink.meta); the device name replaces the value for 1 s on a device
// change; the keyboard light shows three dots instead of a level.
import QtQuick
import qs.core
import qs.components
import "js/notch.js" as NJ

Item {
    id: root

    // The OSD payload (levels.js).
    property var payload: ({})

    // The bulge size: 300 × 44.
    readonly property var _size: NJ.bulgeSize("osd", payload, null, Tokens.surfaces)
    readonly property real bulgeWidth: _size.width
    readonly property real bulgeHeight: _size.height

    // The device name shows instead of the value for osd.deviceNameMs after a payload brought a
    // `device` (the poster sets it only on the first OSD after a device change, levels.js).
    // Wave-2 review: the name is kept for its whole time (the next press brings no device), but
    // only for its own kind (every OSD is one layer, notch.js keyOf: brightness updates it too).
    property bool _deviceShown: false
    property string _deviceName: ""
    property string _deviceKind: ""
    onPayloadChanged: {
        if (payload && payload.device) {
            _deviceName = payload.device;
            _deviceKind = payload.kind || "";
            _deviceShown = true;
            deviceTimer.restart();
        } else if (_deviceShown && !(payload && payload.kind === _deviceKind)) {
            _deviceShown = false;
            deviceTimer.stop();
        }
    }
    Timer {
        id: deviceTimer
        interval: Tokens.surfaces.osd.deviceNameMs
        onTriggered: root._deviceShown = false
    }

    // Found by the probe (phase 5):
    // The OSD's tokens.
    readonly property var _o: Tokens.surfaces.osd

    Row {
        anchors.centerIn: parent
        spacing: Tokens.s5
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            name: root.payload.glyph || ""
            size: root._o.glyphSize
            colour: ComponentShared.ink(root.payload.ink || "main")
        }
        Level {
            visible: (root.payload.level === undefined ? -1 : root.payload.level) >= 0
            anchors.verticalCenter: parent.verticalCenter
            width: root._o.levelWidth
            height: root._o.levelHeight
            value: Math.max(0, root.payload.level || 0) / 100
            max: (root.payload.max || 100) / 100
        }
        Row {
            visible: (root.payload.dots === undefined ? -1 : root.payload.dots) >= 0
            anchors.verticalCenter: parent.verticalCenter
            width: root._o.levelWidth
            spacing: Tokens.s4
            Repeater {
                model: Math.max(0, root.payload.steps || 0)
                delegate: Rectangle {
                    required property int index
                    width: Tokens.pagerDots.size
                    height: width
                    radius: width / 2
                    // one dot per state (off, low, high); the current one in accent
                    color: index === (root.payload.dots || 0) ? Tokens.accent : Tokens.inkFaint
                }
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            type: "body"
            ink: "meta"
            tabular: true
            text: root._deviceShown ? root._deviceName : (root.payload.value || "")
        }
    }
}
