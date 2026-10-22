pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.models
import qs.theme
import qs.components

// Window that hosts one dropdown under a bar item.
PanelWindow {
    id: host

    property var shellState  // ShellState
    property var audioState
    property var batteryState
    property var powerProfileState
    property var calendarState
    property var nightLightState
    property var displayState
    property var networkState
    property var bluetoothState
    signal tileRequested(int tileId)  // a dropdown's More link: open the control center on this tile
    property var anchorItem
    property int dropdownId  // Enums.DropdownId, the dropdown on show (stays during the fade-out)
    readonly property bool isOpen: shellState ? shellState.activeDropdown !== Enums.DropdownId.None : false
    property real appear: isOpen ? 1 : 0  // 0..1
    property real anchorX
    property real anchorWidth
    property var anchorScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    Behavior on appear { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

    // Open under a bar item; a second click on the same item closes it.
    function openAt(id: int, anchor: var, targetScreen: var, offsetX: real = 0): void {
        if (!shellState) return
        if (shellState.activeOverlay !== Enums.Overlay.None) return  // a dropdown never opens over the launcher
        if (shellState.stage !== Enums.Stage.Closed && shellState.stage !== Enums.Stage.Dropdown) return
        if (shellState.activeDropdown === id) {
            closeDropdown()
            return
        }
        const p = anchor.mapToItem(null, 0, 0)
        anchorItem = anchor
        anchorX = p.x + offsetX
        anchorWidth = anchor.width
        anchorScreen = targetScreen
        dropdownId = id
        shellState.openDropdown(id)
    }

    function closeDropdown(): void {
        if (shellState) shellState.closeDropdown()
    }

    screen: anchorScreen
    visible: isOpen || appear > 0.001
    anchors { top: true; bottom: true; left: true; right: true }
    // qmllint disable unqualified unresolved-type
    margins { top: Tokens.barHeight }
    // qmllint enable unqualified unresolved-type
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "aptus-dropdown"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // A click anywhere outside closes the dropdown; the bar itself stays usable (the window starts below it).
    MouseArea {
        anchors.fill: parent
        onClicked: host.closeDropdown()
    }

    Surface {
        id: panel
        elevated: true
        opacity: host.appear
        width: loader.item ? (loader.item as Item).implicitWidth + 28 : 0
        height: loader.item ? (loader.item as Item).implicitHeight + 28 : 0
        // Right edge on the item's right edge, kept 8 px inside the screen. Slides 4 px into place.
        x: Math.max(8, Math.min(host.anchorX + host.anchorWidth - width, host.width - width - 8))
        y: 4 - 4 * (1 - host.appear)

        // Swallow clicks inside the panel so they do not reach the closing area.
        MouseArea {
            anchors.fill: parent
        }

        Loader {
            id: loader
            anchors.fill: parent
            anchors.margins: 14
            focus: true
            Keys.onEscapePressed: host.closeDropdown()
            sourceComponent: {
                switch (host.dropdownId) {
                case Enums.DropdownId.Network: return networkContent
                case Enums.DropdownId.Bluetooth: return bluetoothContent
                case Enums.DropdownId.Audio: return audioContent
                case Enums.DropdownId.Battery: return batteryContent
                case Enums.DropdownId.NightLight: return nightLightContent
                case Enums.DropdownId.Clock: return clockContent
                default: return null
                }
            }
        }
    }

    Component {
        id: networkContent
        NetworkDropdown {
            networkState: host.networkState
            shown: host.isOpen
            onMoreRequested: tileId => host.tileRequested(tileId)
        }
    }
    Component {
        id: bluetoothContent
        BluetoothDropdown {
            bluetoothState: host.bluetoothState
            shown: host.isOpen
            onMoreRequested: tileId => host.tileRequested(tileId)
        }
    }
    Component { id: audioContent; AudioDropdown { audioState: host.audioState; onMoreRequested: tileId => host.tileRequested(tileId) } }
    Component { id: batteryContent; BatteryDropdown { batteryState: host.batteryState; powerProfileState: host.powerProfileState; onMoreRequested: tileId => host.tileRequested(tileId) } }
    Component { id: nightLightContent; NightLightDropdown { nightLightState: host.nightLightState; displayState: host.displayState; onMoreRequested: tileId => host.tileRequested(tileId) } }
    Component { id: clockContent; ClockDropdown { calendarState: host.calendarState; onMoreRequested: tileId => host.tileRequested(tileId) } }
}
