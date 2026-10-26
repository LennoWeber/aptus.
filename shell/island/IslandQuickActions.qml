pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// The lower part of the quick settings card: the power profile and the shortcuts that open a view of the island.
Item {
    id: actions

    property var powerProfileState
    property color ink
    property color inkSoft
    property color line
    property color fill

    signal viewRequested(int view)      // Enums.IslandView

    readonly property var profileNames: ["Saver", "Balanced", "Performance"]
    readonly property var shortcuts: [
        { label: "Screenshot", view: Enums.IslandView.Screenshot },
        { label: "Clipboard", view: Enums.IslandView.Clipboard },
        { label: "Emoji", view: Enums.IslandView.Emoji },
        { label: "Wallpaper", view: Enums.IslandView.Wallpaper },
        { label: "Power", view: Enums.IslandView.Power }
    ]

    implicitHeight: column.implicitHeight

    // Set the power profile (Enums.PowerMode).
    function setProfile(profile: int): void {
        if (profile < Enums.PowerMode.Saver || profile > Enums.PowerMode.Performance) throw new Error("invariant: IslandQuickActions.setProfile: unknown profile")
        if (!powerProfileState) throw new Error("invariant: IslandQuickActions.setProfile: no power profile state")
        powerProfileState.setProfile(profile)
    }

    Column {
        id: column
        width: parent.width
        spacing: 6

        Row {
            visible: actions.powerProfileState !== null && actions.powerProfileState !== undefined
            width: parent.width
            spacing: 6
            Repeater {
                model: actions.powerProfileState ? actions.powerProfileState.availableProfiles : []
                delegate: Rectangle {
                    id: seg
                    required property int modelData
                    readonly property int count: actions.powerProfileState ? actions.powerProfileState.availableProfiles.length : 1
                    readonly property bool current: actions.powerProfileState && actions.powerProfileState.profile === modelData
                    width: (column.width - 6 * (count - 1)) / count
                    height: 30
                    radius: 10
                    color: current ? actions.ink : "transparent"
                    border.width: 1
                    border.color: current ? actions.ink : actions.line
                    Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                    Label { anchors.centerIn: parent; text: actions.profileNames[seg.modelData]; role: Enums.TextRole.Bar; color: seg.current ? actions.fill : actions.ink }
                    MouseArea { anchors.fill: parent; onClicked: actions.setProfile(seg.modelData) }
                }
            }
        }

        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: actions.shortcuts
                delegate: Rectangle {
                    id: pill
                    required property var modelData
                    width: pillLabel.implicitWidth + 24
                    height: 30
                    radius: 15
                    color: "transparent"
                    border.width: 1
                    border.color: actions.line
                    opacity: pillMouse.pressed ? 0.7 : 1
                    Label { id: pillLabel; anchors.centerIn: parent; text: pill.modelData.label; role: Enums.TextRole.Bar; color: actions.ink }
                    MouseArea { id: pillMouse; anchors.fill: parent; onClicked: actions.viewRequested(pill.modelData.view) }
                }
            }
        }
    }
}
