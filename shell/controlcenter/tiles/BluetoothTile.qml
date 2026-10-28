pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the BluetoothTile.
Item {
    id: tile

    property bool expanded
    property var bluetoothState
    readonly property var nothing: []

    // Looking for devices only while the list is on screen.
    onExpandedChanged: {
        if (!bluetoothState) return
        if (expanded && bluetoothState.powered) bluetoothState.startDiscovery()
        else bluetoothState.stopDiscovery()
    }

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Label {
            width: parent.width
            elide: Text.ElideRight
            text: !tile.bluetoothState ? "" : !tile.bluetoothState.powered ? "Off" : (tile.bluetoothState.connectedCount > 0 ? tile.bluetoothState.connectedCount + " connected" : "On")
            font.weight: Font.Medium
            color: !tile.bluetoothState || !tile.bluetoothState.powered ? Tokens.inkFaint : (tile.bluetoothState.connectedCount > 0 ? Tokens.ok : Tokens.ink)
        }
        ToggleSwitch {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            label: "Bluetooth"
            checked: tile.bluetoothState ? tile.bluetoothState.powered : false
            onToggled: on => tile.bluetoothState.setPowered(on)
        }
    }

    // One device: name and state, trusted and forget (paired ones) on the right.
    component DeviceRow: Item {
        id: dev
        required property var modelData
        width: parent ? parent.width : 0
        height: 48

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Tokens.surfaceAlt
            opacity: rowArea.pressed ? 1 : rowArea.containsMouse || dev.modelData.connected ? 0.7 : 0
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
        }
        Rectangle {
            visible: dev.modelData.connected
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: Tokens.ok
        }
        MouseArea {
            id: rowArea
            anchors { left: parent.left; right: controls.left; top: parent.top; bottom: parent.bottom }
            hoverEnabled: true
            onClicked: {
                if (dev.modelData.connected) tile.bluetoothState.disconnectDevice(dev.modelData.address)
                else if (dev.modelData.paired) tile.bluetoothState.connectDevice(dev.modelData.address)
                else tile.bluetoothState.pairDevice(dev.modelData.address)
            }
        }
        Column {
            anchors { left: parent.left; leftMargin: 26; right: controls.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 1
            Label {
                width: parent.width
                elide: Text.ElideRight
                text: dev.modelData.name
                font.weight: Font.Medium
            }
            Label {
                width: parent.width
                elide: Text.ElideRight
                role: Enums.TextRole.Bar
                text: (dev.modelData.connected ? "Connected" : (dev.modelData.paired ? "Paired" : "Tap to pair")) + (dev.modelData.batteryPercent >= 0 ? ", battery " + Math.round(dev.modelData.batteryPercent) + "%" : "")
                color: dev.modelData.connected ? Tokens.ok : Tokens.inkFaint
            }
        }
        Row {
            id: controls
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            spacing: 14
            visible: dev.modelData.paired
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Trusted"
                    role: Enums.TextRole.Bar
                    color: Tokens.inkFaint
                }
                ToggleSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    checked: dev.modelData.trusted
                    onToggled: on => tile.bluetoothState.setTrusted(dev.modelData.address, on)
                }
            }
            ConfirmButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Forget"
                onConfirmed: tile.bluetoothState.forgetDevice(dev.modelData.address)
            }
        }
    }

    component Heading: Item {
        id: heading
        property string text
        property int count: -1
        width: parent ? parent.width : 0
        height: 34
        Label {
            anchors { left: parent.left; leftMargin: 4; bottom: parent.bottom; bottomMargin: 6 }
            text: heading.text + (heading.count >= 0 ? "  " + heading.count : "")
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }
    }

    Column {
        anchors.fill: parent
        visible: tile.expanded
        spacing: 2

        ToggleSwitch {
            width: Math.min(parent.width, 460)
            label: "Bluetooth"
            checked: tile.bluetoothState ? tile.bluetoothState.powered : false
            onToggled: on => {
                tile.bluetoothState.setPowered(on)
                if (on) tile.bluetoothState.startDiscovery()
            }
        }

        Label {
            visible: tile.bluetoothState ? !tile.bluetoothState.powered : false
            leftPadding: 4
            topPadding: 8
            text: "Turn Bluetooth on to see paired and new devices."
            color: Tokens.inkSoft
        }

        Flickable {
            width: parent.width
            height: tile.height - 44
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: tile.bluetoothState ? tile.bluetoothState.powered : false

            Column {
                id: list
                width: parent.width

                Heading { text: "Connected"; count: tile.bluetoothState ? tile.bluetoothState.connectedDevices.length : 0 }
                Repeater {
                    model: tile.bluetoothState ? tile.bluetoothState.connectedDevices : tile.nothing
                    delegate: DeviceRow {}
                }
                Label {
                    visible: tile.bluetoothState && tile.bluetoothState.connectedDevices.length === 0
                    leftPadding: 26
                    text: "No device connected"
                    color: Tokens.inkFaint
                }
                Heading { text: "Paired"; count: tile.bluetoothState ? tile.bluetoothState.pairedDevices.length : 0 }
                Repeater {
                    model: tile.bluetoothState ? tile.bluetoothState.pairedDevices : tile.nothing
                    delegate: DeviceRow {}
                }
                Label {
                    visible: tile.bluetoothState && tile.bluetoothState.pairedDevices.length === 0
                    leftPadding: 26
                    text: "No paired device"
                    color: Tokens.inkFaint
                }
                Heading { text: tile.bluetoothState && tile.bluetoothState.discovering ? "New devices (searching)" : "New devices"; count: tile.bluetoothState ? tile.bluetoothState.newDevices.length : 0 }
                Repeater {
                    model: tile.bluetoothState ? tile.bluetoothState.newDevices : tile.nothing
                    delegate: DeviceRow {}
                }
                Label {
                    visible: tile.bluetoothState && tile.bluetoothState.newDevices.length === 0
                    leftPadding: 26
                    text: "Nothing new found"
                    color: Tokens.inkFaint
                }
            }
        }
    }
}
