pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.services

// Popup notifications: opaque cards under the bar, newest on top; held back while do-not-disturb is on.
PanelWindow {
    id: win

    property string position: "top-right"  // top-right | top-left | top-center
    readonly property var items: Notifications.popupItems

    function pickScreen(monitor: var): var {
        const list = Quickshell.screens
        if (monitor) for (const s of list) if (s.name === monitor.name) return s
        return list.length > 0 ? list[0] : null
    }

    screen: pickScreen(Hyprland.focusedMonitor)
    visible: items.length > 0
    anchors {
        top: true
        right: win.position === "top-right"
        left: win.position === "top-left"
    }
    // qmllint disable unqualified unresolved-type
    margins {
        top: Tokens.barHeight + 8
        right: 12
        left: 12
    }
    // qmllint enable unqualified unresolved-type
    implicitWidth: 360
    implicitHeight: column.height
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aptus-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Column {
        id: column
        width: parent.width
        spacing: 8

        add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Tokens.durFast } }
        move: Transition { NumberAnimation { property: "y"; duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

        Repeater {
            model: win.items
            delegate: NotificationCard {
                required property var modelData
                width: column.width
                popup: true
                item: modelData
                onActivated: Notifications.hidePopup(modelData.id)
                onCloseRequested: Notifications.dismiss(modelData.id)
                onActionInvoked: actionId => Notifications.invoke(modelData.id, actionId)
            }
        }
    }
}
