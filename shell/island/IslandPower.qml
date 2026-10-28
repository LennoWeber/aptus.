pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.services
import qs.components

// Power view: lock, log out, restart, shut down. Never suspend or hibernate. Restart and shut down need a second tap.
FocusScope {
    id: power

    property var lockState  // LockState
    property string armed   // id of the action waiting for its second tap
    property int selectedIndex
    property var actions: defaultActions    // { id, label, glyph }
    property color ink
    property color inkSoft
    property color line
    property real outerRadius: 22       // corner radius of the island body: inner shapes take outerRadius minus their margin

    signal closeRequested()

    readonly property real cellMargin: 14     // distance of the tiles from the body's edge
    readonly property real cellSpacing: 10

    // Width of one tile when count tiles share a row of total px: margins left and right, spacing between.
    function cellWidth(total: real, count: int): real {
        if (!(count > 0)) throw new Error("invariant: IslandPower.cellWidth: there must be at least one tile")
        throw new Error("not implemented")
    }

    readonly property var defaultActions: [
        { id: "lock", label: "Lock", glyph: "lock" },
        { id: "logout", label: "Log out", glyph: "logout" },
        { id: "restart", label: "Restart", glyph: "restart" },
        { id: "shutdown", label: "Shut down", glyph: "power" }
    ]

    Timer { id: armTimer; interval: 4000; onTriggered: power.armed = "" }

    // Run an action; restart and shut down need a second tap within a few seconds.
    function run(actionId: string): void {
        if ((actionId === "restart" || actionId === "shutdown") && armed !== actionId) {
            armed = actionId
            armTimer.restart()
            return
        }
        closeRequested()
        if (actionId === "lock") lockState.lock()
        else if (actionId === "logout") Session.logout()
        else if (actionId === "restart") Session.restart()
        else if (actionId === "shutdown") Session.shutdown()
    }

    function moveSelection(delta: int): void {
        selectedIndex = (selectedIndex + delta + actions.length) % actions.length
        armed = ""
    }

    function activateSelected(): void {
        run(actions[selectedIndex].id)
    }

    // Reset the armed action and the selection when the view is shown.
    function reset(): void {
        armed = ""
        selectedIndex = 0
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) { moveSelection(-1); event.accepted = true }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { moveSelection(1); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { activateSelected(); event.accepted = true }
        else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) { selectedIndex = event.key - Qt.Key_1; activateSelected(); event.accepted = true }
    }

    // TODO(phase 7, style): the tiles share the width through cellWidth(width, actions.length) and take the height minus 2 * cellMargin; the Row is anchored with cellMargin, not centred with fixed cells.
    Row {
        anchors.centerIn: parent
        spacing: 10

        Repeater {
            model: power.actions
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool isArmed: power.armed === modelData.id
                readonly property bool isSelected: power.selectedIndex === index
                width: 104
                height: 118

                Rectangle {
                    anchors.fill: parent
                    // TODO(phase 7, style): tile radius = outerRadius minus cellMargin (also for the outline below); glyph and label sit relative to the tile height, not at fixed y.
                    radius: 14
                    color: power.ink
                    opacity: tap.pressed ? 0.16 : (tap.containsMouse || cell.isSelected) ? 0.09 : 0.04
                    Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"
                    border.width: cell.isArmed ? 1.5 : cell.isSelected ? 1 : 0
                    border.color: cell.isArmed ? Tokens.critical : power.ink
                }
                StatusGlyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 30
                    kind: cell.modelData.glyph
                    width: 28
                    height: 28
                    color: cell.isArmed ? Tokens.critical : power.ink
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 76
                    text: cell.isArmed ? "Tap again" : cell.modelData.label
                    color: cell.isArmed ? Tokens.critical : power.ink
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: tap
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { power.selectedIndex = cell.index; power.run(cell.modelData.id) }
                }
            }
        }
    }
}
