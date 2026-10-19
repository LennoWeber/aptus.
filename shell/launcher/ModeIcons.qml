pragma ComponentBehavior: Bound
import QtQuick
import qs.theme
import qs.components

// Floating mode symbols next to the pill.
Item {
    id: icons

    property var modes: [0, 1, 2, 3, 4]  // list of Enums.LauncherMode
    property int currentMode
    property int previousMode
    property real mergeProgress: 1  // 0..1
    signal modeClicked(int mode)

    readonly property int cell: 34

    implicitWidth: modes.length * cell + 12
    implicitHeight: 52

    function animateTo(newMode: int): void {
        modeClicked(newMode)
    }

    Surface {
        anchors.fill: parent
        cornerRadius: Tokens.radiusPill
        elevated: true
    }

    // The chosen symbol sits on a soft round that glides to it.
    Rectangle {
        y: (parent.height - icons.cell + 6) / 2
        width: icons.cell - 6
        height: width
        radius: width / 2
        color: Tokens.surfaceAlt
        x: 6 + icons.modes.indexOf(icons.currentMode) * icons.cell + 3
        Behavior on x { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    }

    Repeater {
        model: icons.modes
        delegate: Item {
            id: slot
            required property int modelData
            required property int index
            x: 6 + index * icons.cell
            width: icons.cell
            height: icons.height

            ModeGlyph {
                anchors.centerIn: parent
                mode: slot.modelData
                color: slot.modelData === icons.currentMode ? Tokens.ink : hover.containsMouse ? Tokens.inkSoft : Tokens.inkFaint
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                onClicked: icons.modeClicked(slot.modelData)
            }
        }
    }
}
