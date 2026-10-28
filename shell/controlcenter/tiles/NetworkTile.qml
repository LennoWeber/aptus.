pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the NetworkTile.
Item {
    id: tile

    property bool expanded
    property var networkState
    property string passwordFor  // the new network whose password is being typed
    property bool hiddenOpen     // the form for a hidden network is open
    readonly property var link: networkState && networkState.linkDetails ? networkState.linkDetails : ({})

    // Scanning only while the list is on screen.
    onExpandedChanged: {
        if (!networkState) return
        if (expanded) { networkState.refreshSaved(); networkState.refreshLink() }
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

    // A small heading with a count.
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

    // A saved network: name and state, auto-connect and forget on the right.
    component SavedRow: Item {
        id: saved
        required property var modelData
        width: parent ? parent.width : 0
        height: 48

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Tokens.surfaceAlt
            opacity: rowArea.pressed ? 1 : rowArea.containsMouse || saved.modelData.connected ? 0.7 : 0
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
        }
        Rectangle {
            visible: saved.modelData.connected
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
                if (saved.modelData.connected) tile.networkState.disconnectWifi()
                else if (saved.modelData.inRange) tile.networkState.connectSaved(saved.modelData.name)
            }
        }
        Column {
            anchors { left: parent.left; leftMargin: 26; right: controls.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 1
            Label {
                width: parent.width
                elide: Text.ElideRight
                text: saved.modelData.name
                font.weight: Font.Medium
                color: saved.modelData.inRange ? Tokens.ink : Tokens.inkSoft
            }
            Label {
                width: parent.width
                elide: Text.ElideRight
                role: Enums.TextRole.Bar
                text: saved.modelData.connected ? "Connected" : (saved.modelData.inRange ? "In range, " + Math.round(saved.modelData.signal * 100) + "%" : "Out of range")
                color: saved.modelData.connected ? Tokens.ok : Tokens.inkFaint
            }
        }
        Row {
            id: controls
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            spacing: 14
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Auto"
                    role: Enums.TextRole.Bar
                    color: Tokens.inkFaint
                }
                ToggleSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    checked: saved.modelData.autoconnect
                    onToggled: on => tile.networkState.setAutoconnect(saved.modelData.name, on)
                }
            }
            ConfirmButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Forget"
                onConfirmed: tile.networkState.forgetSaved(saved.modelData.name)
            }
        }
    }

    // One line of the link details.
    component Fact: Row {
        id: fact
        property string name
        property string value
        visible: value !== ""
        spacing: 10
        Label { width: 84; text: fact.name; role: Enums.TextRole.Bar; color: Tokens.inkFaint; anchors.verticalCenter: parent.verticalCenter }
        Label { text: fact.value; role: Enums.TextRole.Mono; anchors.verticalCenter: parent.verticalCenter }
    }

    // Expanded: the current link on the left, saved and new networks on the right.
    Item {
        anchors.fill: parent
        visible: tile.expanded

        Column {
            id: left
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: Math.min(360, parent.width * 0.38)
            spacing: 6

            ToggleSwitch {
                width: parent.width
                label: "Wi-Fi"
                checked: tile.networkState ? tile.networkState.wifiEnabled : false
                onToggled: on => {
                    tile.networkState.setWifiEnabled(on)
                    if (on) tile.networkState.scan()
                }
            }
            Item { width: 1; height: 8 }
            Label { text: "Connected"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            Row {
                spacing: 12
                visible: tile.networkState ? tile.networkState.connected : false
                Bars {
                    anchors.verticalCenter: parent.verticalCenter
                    level: tile.networkState ? tile.networkState.signalStrength : 0
                    activeColor: Tokens.ok
                }
                Label {
                    width: left.width - 40
                    elide: Text.ElideRight
                    text: tile.networkState ? tile.networkState.ssid : ""
                    role: Enums.TextRole.Title
                }
            }
            Label {
                visible: !(tile.networkState && tile.networkState.connected)
                text: tile.networkState && tile.networkState.wifiEnabled ? "Not connected to a Wi-Fi network" : "Wi-Fi is off"
                color: Tokens.inkSoft
            }
            Item { width: 1; height: 4; visible: tile.networkState && tile.networkState.connected }
            Fact { name: "IP address"; value: tile.link.ip || "" }
            Fact { name: "Gateway"; value: tile.link.gateway || "" }
            Fact { name: "DNS"; value: tile.link.dns || "" }
            Fact { name: "Band"; value: tile.link.band ? tile.link.band + ", channel " + tile.link.channel : "" }
            Fact { name: "Speed"; value: tile.link.rate || "" }
            Fact { name: "Security"; value: tile.link.security || "" }
            Item { width: 1; height: 10; visible: tile.networkState && tile.networkState.connected }
            Row {
                visible: tile.networkState ? tile.networkState.connected : false
                spacing: 8
                ActionButton {
                    text: "Disconnect"
                    onClicked: tile.networkState.disconnectWifi()
                }
            }
            Item { width: 1; height: 10; visible: tile.networkState && tile.networkState.ethernetConnected }
            Label { visible: tile.networkState ? tile.networkState.ethernetConnected : false; text: "Ethernet"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            Fact { name: "IP address"; value: tile.networkState && tile.networkState.ethernetConnected ? tile.networkState.ethernetIp : "" }
        }

        Rectangle {
            id: divider
            anchors { left: left.right; leftMargin: 24; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Tokens.line
        }

        Flickable {
            anchors { left: divider.right; leftMargin: 24; right: parent.right; top: parent.top; bottom: parent.bottom }
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: tile.networkState ? tile.networkState.wifiEnabled : false

            Column {
                id: list
                width: parent.width

                Heading { text: "Saved"; count: tile.networkState ? tile.networkState.savedNetworks.length : 0 }
                Repeater {
                    model: tile.networkState ? tile.networkState.savedNetworks : []
                    delegate: SavedRow {}
                }

                Heading { text: tile.networkState && tile.networkState.scanning ? "New networks (scanning)" : "New networks"; count: tile.networkState ? tile.networkState.newNetworks.length : 0 }
                Repeater {
                    model: tile.networkState ? tile.networkState.newNetworks : []
                    delegate: Column {
                        id: entry
                        required property var modelData
                        width: list.width

                        ListRow {
                            width: parent.width
                            title: entry.modelData.ssid
                            subtitle: entry.modelData.secured ? "Secured" : "Open"
                            trailing: Math.round(entry.modelData.signal * 100) + "%"
                            onClicked: {
                                if (entry.modelData.secured) tile.passwordFor = tile.passwordFor === entry.modelData.ssid ? "" : entry.modelData.ssid
                                else tile.networkState.connectTo(entry.modelData.ssid, "")
                            }
                        }

                        Item {
                            visible: tile.passwordFor === entry.modelData.ssid
                            width: parent.width
                            height: visible ? 48 : 0
                            InputField {
                                id: pass
                                anchors { fill: parent; leftMargin: 26; rightMargin: 90; topMargin: 4; bottomMargin: 4 }
                                placeholder: "Password"
                                secret: true
                                onAccepted: join.clicked()
                            }
                            ActionButton {
                                id: join
                                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                width: 80
                                height: 36
                                text: "Connect"
                                primary: true
                                onClicked: {
                                    tile.networkState.connectTo(entry.modelData.ssid, pass.text)
                                    tile.passwordFor = ""
                                    pass.text = ""
                                }
                            }
                        }
                    }
                }

                Label {
                    visible: tile.networkState && tile.networkState.newNetworks.length === 0
                    leftPadding: 26
                    text: "Nothing new in range"
                    color: Tokens.inkFaint
                }

                Heading { text: "Other" }
                ListRow {
                    width: parent.width
                    title: "Hidden network"
                    subtitle: "Join by name"
                    selected: tile.hiddenOpen
                    onClicked: tile.hiddenOpen = !tile.hiddenOpen
                }
                Item {
                    visible: tile.hiddenOpen
                    width: parent.width
                    height: visible ? 100 : 0
                    Column {
                        anchors { fill: parent; leftMargin: 26; topMargin: 4 }
                        spacing: 6
                        InputField { id: hiddenName; width: parent.width - 4; height: 36; placeholder: "Network name" }
                        Item {
                            width: parent.width - 4
                            height: 36
                            InputField { id: hiddenPass; anchors { left: parent.left; right: join2.left; rightMargin: 8; top: parent.top; bottom: parent.bottom } placeholder: "Password (empty if open)"; secret: true }
                            ActionButton {
                                id: join2
                                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                                width: 80
                                text: "Join"
                                primary: true
                                active: hiddenName.text !== ""
                                onClicked: {
                                    tile.networkState.connectHidden(hiddenName.text, hiddenPass.text)
                                    hiddenName.text = ""
                                    hiddenPass.text = ""
                                    tile.hiddenOpen = false
                                }
                            }
                        }
                    }
                }
            }
        }

        Label {
            visible: tile.networkState ? !tile.networkState.wifiEnabled : false
            anchors { left: divider.right; leftMargin: 24; top: parent.top; topMargin: 8 }
            text: "Turn Wi-Fi on to see saved and new networks."
            color: Tokens.inkSoft
        }
    }
}
