pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.services
import qs.components

// Content of the NetworkTile.
Item {
    id: tile

    property bool expanded
    property var networkState
    property string passwordFor  // the network whose password is being typed

    // Scanning only while the list is on screen.
    onExpandedChanged: {
        if (!networkState) return
        if (expanded && networkState.wifiEnabled) networkState.scan()
        else networkState.stopScan()
    }

    // Signal strength as four small bars.
    component Bars: Item {
        id: bars
        property real level: 0
        property color activeColor: Tokens.ink
        implicitWidth: 18
        implicitHeight: 13
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                x: index * 5
                y: bars.height - height
                width: 3
                height: 4 + index * 3
                radius: 1
                color: bars.level >= (index + 1) / 4.5 ? bars.activeColor : Tokens.line
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Label {
            width: parent.width - 50
            elide: Text.ElideRight
            text: !tile.networkState ? "" : !tile.networkState.wifiEnabled ? "Wi-Fi off" : (tile.networkState.connected ? tile.networkState.ssid : (tile.networkState.ethernetConnected ? "Ethernet" : "Not connected"))
            font.weight: Font.Medium
            color: !tile.networkState || !tile.networkState.wifiEnabled ? Tokens.inkFaint : ((tile.networkState.connected || tile.networkState.ethernetConnected) ? Tokens.ok : Tokens.ink)
        }
        Bars {
            anchors { right: parent.right; top: parent.top }
            level: tile.networkState && tile.networkState.connected ? tile.networkState.signalStrength : 0
            activeColor: Tokens.ok
        }
        ToggleSwitch {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            label: "Wi-Fi"
            checked: tile.networkState ? tile.networkState.wifiEnabled : false
            onToggled: on => tile.networkState.setWifiEnabled(on)
        }
    }

    Column {
        anchors.fill: parent
        visible: tile.expanded
        spacing: 2

        ToggleSwitch {
            width: parent.width
            label: "Wi-Fi"
            checked: tile.networkState ? tile.networkState.wifiEnabled : false
            onToggled: on => {
                tile.networkState.setWifiEnabled(on)
                if (on) tile.networkState.scan()
            }
        }

        Label {
            visible: tile.networkState && tile.networkState.wifiEnabled
            text: tile.networkState && tile.networkState.scanning ? "Networks (scanning)" : "Networks"
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }

        Flickable {
            width: parent.width
            height: tile.height - 90
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list
                width: parent.width
                Repeater {
                    model: tile.networkState && tile.networkState.wifiEnabled ? tile.networkState.networks : []
                    delegate: Column {
                        id: entry
                        required property var modelData
                        width: list.width

                        ListRow {
                            width: parent.width
                            title: entry.modelData.ssid
                            subtitle: entry.modelData.connected ? "Connected" : (entry.modelData.known ? "Saved" : (entry.modelData.secured ? "Secured" : "Open"))
                            trailing: Math.round(entry.modelData.signal * 100) + "%"
                            selected: entry.modelData.connected
                            dotColor: Tokens.ok
                            onClicked: {
                                if (entry.modelData.connected) tile.networkState.disconnectWifi()
                                else if (entry.modelData.secured && !entry.modelData.known) tile.passwordFor = tile.passwordFor === entry.modelData.ssid ? "" : entry.modelData.ssid
                                else tile.networkState.connectTo(entry.modelData.ssid, "")
                            }
                        }

                        // Password row for a secured network that is not saved yet.
                        Item {
                            visible: tile.passwordFor === entry.modelData.ssid
                            width: parent.width
                            height: visible ? 44 : 0

                            Surface {
                                anchors { fill: parent; leftMargin: 26; rightMargin: 4; topMargin: 2; bottomMargin: 2 }
                                cornerRadius: 10
                                TextInput {
                                    id: pass
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 90 }
                                    verticalAlignment: TextInput.AlignVCenter
                                    echoMode: TextInput.Password
                                    font.family: Tokens.fontUi
                                    font.pixelSize: Tokens.sizeBody
                                    color: Tokens.ink
                                    clip: true
                                    onAccepted: connectButton.go()
                                    onActiveFocusChanged: Osk.track(pass, activeFocus)
                                    Text {
                                        visible: pass.text === ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Password"
                                        font: pass.font
                                        color: Tokens.inkFaint
                                    }
                                }
                                Item {
                                    id: connectButton
                                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: 6 }
                                    width: 76
                                    function go(): void {
                                        tile.networkState.connectTo(entry.modelData.ssid, pass.text)
                                        tile.passwordFor = ""
                                        pass.text = ""
                                    }
                                    Rectangle { anchors { fill: parent; margins: 5 } radius: 8; color: Tokens.ink }
                                    Label { anchors.centerIn: parent; text: "Connect"; color: Tokens.bg }
                                    MouseArea { anchors.fill: parent; onClicked: connectButton.go() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
