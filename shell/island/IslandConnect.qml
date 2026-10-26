pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// The list under the switches of the card: the Wi-Fi networks or the Bluetooth devices, with the power switch of that radio.
// A tap on a row connects. Scanning and discovery run only while the list is shown.
FocusScope {
    id: connect

    property string section             // "", "wifi" or "bluetooth"
    property var networkState
    property var bluetoothState
    property color ink
    property color inkSoft
    property color line
    property color fill

    signal closeRequested()

    onSectionChanged: if (section !== "" && section !== "wifi" && section !== "bluetooth") throw new Error("invariant: IslandConnect: unknown section")

    readonly property bool isWifi: section === "wifi"
    readonly property bool radioOn: isWifi ? (networkState ? networkState.wifiEnabled : false) : (bluetoothState ? bluetoothState.powered : false)
    readonly property string value: isWifi
        ? (radioOn ? (networkState && networkState.ssid ? networkState.ssid : "Not connected") : "Off")
        : (radioOn ? (bluetoothState && bluetoothState.connectedCount > 0 ? bluetoothState.connectedCount + " connected" : "On") : "Off")

    implicitHeight: section === "" ? 0 : column.implicitHeight + 4
    clip: true
    Keys.onEscapePressed: closeRequested()

    function setRadio(on: bool): void {
        if (isWifi) { if (networkState) networkState.setWifiEnabled(on) }
        else if (bluetoothState) bluetoothState.setPowered(on)
    }

    Column {
        id: column
        width: parent.width
        spacing: 2

        Item {
            width: parent.width
            height: 36
            Label { id: title; anchors { left: parent.left; verticalCenter: parent.verticalCenter } text: connect.isWifi ? "Wi-Fi" : "Bluetooth"; color: connect.ink; font.weight: Font.DemiBold }
            Label {
                anchors { left: title.right; leftMargin: 10; right: sw.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                text: connect.value
                role: Enums.TextRole.Bar
                color: connect.inkSoft
                elide: Text.ElideRight
            }
            Rectangle {
                id: sw
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 36; height: 20; radius: 10
                color: connect.radioOn ? connect.ink : "transparent"
                border.width: 1
                border.color: connect.radioOn ? connect.ink : connect.line
                Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                Rectangle {
                    width: 14; height: 14; radius: 7
                    anchors.verticalCenter: parent.verticalCenter
                    x: connect.radioOn ? parent.width - width - 3 : 3
                    color: connect.radioOn ? connect.fill : connect.inkSoft
                    Behavior on x { NumberAnimation { duration: Tokens.durFast } }
                }
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: connect.setRadio(!connect.radioOn) }
            }
        }
        IslandWifi {
            visible: connect.isWifi
            width: parent.width
            height: visible ? implicitHeight : 0
            networkState: connect.networkState
            shown: connect.isWifi
            ink: connect.ink; inkSoft: connect.inkSoft; line: connect.line; fill: connect.fill
            onCloseRequested: connect.closeRequested()
        }
        IslandBluetooth {
            visible: connect.section === "bluetooth"
            width: parent.width
            height: visible ? implicitHeight : 0
            bluetoothState: connect.bluetoothState
            shown: connect.section === "bluetooth"
            ink: connect.ink; inkSoft: connect.inkSoft; line: connect.line; fill: connect.fill
            onCloseRequested: connect.closeRequested()
        }
    }
}
