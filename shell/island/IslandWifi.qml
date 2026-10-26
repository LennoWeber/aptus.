pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// The Wi-Fi section of the hover card: the nearby networks, a tap connects, a secured network that is not saved asks for
// its password in a row under it. Scanning runs only while the section is shown.
FocusScope {
    id: wifi

    property var networkState
    property bool shown                 // true while the section is open: scanning only then
    property string passwordFor         // the network whose password is being typed
    property int maxRows: 5
    property color ink
    property color inkSoft
    property color line
    property color fill

    readonly property bool wifiOn: networkState ? networkState.wifiEnabled : false
    readonly property var nearby: networkState && wifiOn ? networkState.networks.slice(0, maxRows) : []

    implicitHeight: column.implicitHeight

    // Scanning runs only while the section is shown.
    onShownChanged: {
        if (!networkState) return
        if (shown && wifiOn) networkState.scan()
        else { passwordFor = ""; networkState.stopScan() }
    }
    Component.onDestruction: if (networkState) networkState.stopScan()
    Keys.onEscapePressed: closeRequested()

    // A password is only asked for while the section is shown.
    onPasswordForChanged: if (passwordFor !== "" && !shown) throw new Error("invariant: IslandWifi: password row while the section is closed")

    signal closeRequested()

    // A tap on a network: connect or disconnect, ask for the password, or connect to a saved one.
    function tapNetwork(ssid: string, secured: bool, known: bool, connected: bool): void {
        if (!ssid) throw new Error("invariant: IslandWifi.tapNetwork: empty network name")
        if (!networkState) throw new Error("invariant: IslandWifi.tapNetwork: no network state")
        if (connected) networkState.disconnectWifi()
        else if (secured && !known) passwordFor = passwordFor === ssid ? "" : ssid
        else connectTo(ssid, "")
    }

    // Connect to a network with the typed password (an empty one for an open or saved network).
    function connectTo(ssid: string, password: string): void {
        if (!ssid) throw new Error("invariant: IslandWifi.connectTo: empty network name")
        if (!networkState || !networkState.wifiEnabled) throw new Error("invariant: IslandWifi.connectTo: Wi-Fi is off")
        networkState.connectTo(ssid, password)
        passwordFor = ""
    }

    Column {
        id: column
        width: parent.width

        Label {
            visible: !wifi.wifiOn || wifi.nearby.length === 0
            height: visible ? 30 : 0
            verticalAlignment: Text.AlignVCenter
            text: !wifi.wifiOn ? "Wi-Fi is off" : wifi.networkState && wifi.networkState.scanning ? "Scanning…" : "No networks found"
            role: Enums.TextRole.Bar
            color: wifi.inkSoft
        }

        Repeater {
            model: wifi.nearby
            delegate: Column {
                id: entry
                required property var modelData
                width: column.width

                Item {
                    width: parent.width
                    height: 34
                    Rectangle {
                        visible: entry.modelData.connected
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        width: 6; height: 6; radius: 3
                        color: Tokens.ok
                    }
                    Label {
                        anchors { left: parent.left; leftMargin: 14; right: sub.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: entry.modelData.ssid
                        role: Enums.TextRole.Bar
                        elide: Text.ElideRight
                        color: wifi.ink
                        font.weight: entry.modelData.connected ? Font.DemiBold : Font.Normal
                    }
                    Label {
                        id: sub
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: (entry.modelData.connected ? "Connected  " : entry.modelData.known ? "Saved  " : entry.modelData.secured ? "Secured  " : "Open  ") + Math.round(entry.modelData.signal * 100) + "%"
                        role: Enums.TextRole.Bar
                        color: wifi.inkSoft
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: wifi.tapNetwork(entry.modelData.ssid, entry.modelData.secured, entry.modelData.known, entry.modelData.connected)
                    }
                }

                // Password row for a secured network that is not saved yet.
                Item {
                    visible: wifi.passwordFor === entry.modelData.ssid
                    width: parent.width
                    height: visible ? 40 : 0
                    onVisibleChanged: if (visible) pass.forceActiveFocus()
                    Rectangle {
                        anchors { fill: parent; margins: 3 }
                        radius: 10
                        color: "transparent"
                        border.width: 1
                        border.color: wifi.line
                        TextInput {
                            id: pass
                            anchors { fill: parent; leftMargin: 12; rightMargin: 84 }
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.sizeBody
                            color: wifi.ink
                            clip: true
                            onAccepted: { wifi.connectTo(entry.modelData.ssid, text); text = "" }
                            Text {
                                visible: pass.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Password"
                                font: pass.font
                                color: wifi.inkSoft
                            }
                        }
                        Rectangle {
                            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; margins: 4 }
                            width: 72
                            radius: 8
                            color: wifi.ink
                            Label { anchors.centerIn: parent; text: "Connect"; role: Enums.TextRole.Bar; color: wifi.fill }
                            MouseArea { anchors.fill: parent; onClicked: { wifi.connectTo(entry.modelData.ssid, pass.text); pass.text = "" } }
                        }
                    }
                }
            }
        }
    }
}
