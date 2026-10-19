pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the network dropdown: Wi-Fi switch, the nearby networks, a link to the control center.
Item {
    id: dd

    property var networkState
    property bool shown  // true while the dropdown is on screen: scanning only then
    signal moreRequested(int tileId)  // opens the control center on a tile

    readonly property bool wifiOn: networkState ? networkState.wifiEnabled : false
    readonly property var nearby: networkState && wifiOn ? networkState.networks.slice(0, 6) : []

    onShownChanged: {
        if (!networkState) return
        if (shown && wifiOn) networkState.scan()
        else networkState.stopScan()
    }
    Component.onDestruction: if (networkState) networkState.stopScan()

    implicitWidth: 320
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 2

        ToggleSwitch {
            width: parent.width
            label: "Wi-Fi"
            checked: dd.wifiOn
            onToggled: on => {
                dd.networkState.setWifiEnabled(on)
                if (on) dd.networkState.scan()
            }
        }

        Label {
            visible: dd.networkState && !dd.wifiOn && dd.networkState.ethernetConnected
            text: "Connected by Ethernet"
            color: Tokens.ok
        }

        Label {
            visible: dd.wifiOn
            text: dd.networkState && dd.networkState.scanning ? "Networks (scanning)" : "Networks"
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }

        Repeater {
            model: dd.nearby
            delegate: ListRow {
                id: row
                required property var modelData
                width: column.width
                title: modelData.ssid
                subtitle: modelData.connected ? "Connected" : (modelData.known ? "Saved" : (modelData.secured ? "Secured" : "Open"))
                trailing: Math.round(modelData.signal * 100) + "%"
                selected: modelData.connected
                dotColor: Tokens.ok
                onClicked: {
                    if (modelData.connected) dd.networkState.disconnectWifi()
                    else if (modelData.secured && !modelData.known) dd.moreRequested(Enums.TileId.Network)   // needs a password
                    else dd.networkState.connectTo(modelData.ssid, "")
                }
            }
        }

        Label {
            visible: dd.wifiOn && dd.nearby.length === 0
            text: "No networks found yet"
            color: Tokens.inkSoft
        }

        Item { width: 1; height: 6 }
        ActionButton {
            text: "More"
            onClicked: dd.moreRequested(Enums.TileId.Network)
        }
    }
}
