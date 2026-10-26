pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// The opened Home in one of three styles (setting island.homeStyle): dashboard, bento or paper. All three have the same
// content: time, volume and brightness, the switches, music, the workspaces and the shortcuts. A tap on Wi-Fi or Bluetooth
// opens the list of networks or devices under the switches, where a tap connects.
FocusScope {
    id: card

    property string style: "dashboard"
    property var appSettings
    property var audioState
    property var displayState
    property var networkState
    property var bluetoothState
    property var batteryState
    property var nightLightState
    property var caffeineState
    property var focusState
    property var mediaState
    property var powerProfileState
    property var workspaces
    property string workspaceStyle
    property string clockFormat
    property color inkOn            // for the number inside the active bubble
    property color ink
    property color inkSoft
    property color line
    property color fill
    property string expanded        // the open list: "", "wifi" or "bluetooth"

    signal closeRequested()
    signal viewRequested(int view)
    signal sectionToggled(string name)
    signal controlCenterRequested()

    readonly property var styles: ["dashboard", "bento", "paper"]
    // The width of the card for a style.
    function widthFor(styleName: string): real {
        if (styles.indexOf(styleName) < 0) throw new Error("invariant: IslandCard.widthFor: unknown style " + styleName)
        return styleName === "bento" ? 560 : styleName === "paper" ? 460 : 520
    }
    onStyleChanged: if (styles.indexOf(style) < 0) throw new Error("invariant: IslandCard: unknown style " + style)
    onExpandedChanged: if (expanded !== "" && expanded !== "wifi" && expanded !== "bluetooth") throw new Error("invariant: IslandCard: unknown list")

    SystemClock { id: sys; precision: SystemClock.Minutes }
    readonly property var english: Qt.locale("en_GB")
    readonly property string timeText: english.toString(sys.date, clockFormat === "12h" ? "h:mm AP" : "HH:mm")
    readonly property string dateText: english.toString(sys.date, "dddd d MMMM")
    readonly property color tileColor: Qt.rgba(ink.r, ink.g, ink.b, 0.07)
    readonly property bool playerShown: mediaState ? mediaState.available : false

    // Open the list of name, or close it when it is open; a radio that is off is switched on.
    function toggleSection(name: string): void {
        if (name !== "wifi" && name !== "bluetooth") throw new Error("invariant: IslandCard.toggleSection: unknown list")
        if (expanded === name) { expanded = ""; sectionToggled(""); return }
        if (name === "wifi" && networkState && !networkState.wifiEnabled) networkState.setWifiEnabled(true)
        if (name === "bluetooth" && bluetoothState && !bluetoothState.powered) bluetoothState.setPowered(true)
        expanded = name
        sectionToggled(name)
    }

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width

        Loader {
            id: layout
            width: parent.width
            height: (item as Item)?.implicitHeight ?? 0
            sourceComponent: card.style === "bento" ? bento : card.style === "paper" ? paper : dashboard
        }
        Item {
            width: parent.width
            height: connect.implicitHeight
            IslandConnect {
                id: connect
                anchors { left: parent.left; right: parent.right; margins: card.style === "bento" ? 14 : 18 }
                section: card.expanded
                networkState: card.networkState
                bluetoothState: card.bluetoothState
                ink: card.ink; inkSoft: card.inkSoft; line: card.line; fill: card.fill
                onCloseRequested: card.closeRequested()
            }
        }
        Item {
            width: parent.width
            height: actions.implicitHeight + 18
            IslandQuickActions {
                id: actions
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: card.style === "bento" ? 14 : 18; topMargin: 4 }
                powerProfileState: card.powerProfileState
                ink: card.ink; inkSoft: card.inkSoft; line: card.line; fill: card.fill
                onViewRequested: v => card.viewRequested(v)
            }
        }
    }

    Component { id: dashboard; IslandCardDashboard { card: card; width: layout.width } }
    Component { id: bento; IslandCardBento { card: card; width: layout.width } }
    Component { id: paper; IslandCardPaper { card: card; width: layout.width } }
}
