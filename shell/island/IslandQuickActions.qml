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

        // The power profile: one track with a sliding thumb.
        Rectangle {
            id: track
            readonly property var profiles: actions.powerProfileState ? actions.powerProfileState.availableProfiles : []
            readonly property int count: Math.max(1, profiles.length)
            readonly property int currentIndex: actions.powerProfileState ? profiles.indexOf(actions.powerProfileState.profile) : -1
            visible: actions.powerProfileState !== null && actions.powerProfileState !== undefined
            width: parent.width
            height: 34
            radius: 12
            color: Qt.rgba(actions.ink.r, actions.ink.g, actions.ink.b, 0.06)

            Rectangle {
                visible: track.currentIndex >= 0
                x: 3 + Math.max(0, track.currentIndex) * width
                y: 3
                width: (track.width - 6) / track.count
                height: track.height - 6
                radius: 9
                color: actions.ink
                Behavior on x { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.OutCubic } }
            }
            Row {
                x: 3
                y: 3
                Repeater {
                    model: track.profiles
                    delegate: Item {
                        id: seg
                        required property int modelData
                        readonly property bool current: actions.powerProfileState && actions.powerProfileState.profile === modelData
                        width: (track.width - 6) / track.count
                        height: track.height - 6
                        Label {
                            anchors.centerIn: parent
                            text: actions.profileNames[seg.modelData]
                            role: Enums.TextRole.Bar
                            font.weight: seg.current ? Font.Medium : Font.Normal
                            color: seg.current ? actions.fill : actions.inkSoft
                            Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                        }
                        MouseArea { anchors.fill: parent; onClicked: actions.setProfile(seg.modelData) }
                    }
                }
            }
        }

        // The shortcuts: equal tiles across the row, the same corner as the switches above.
        Row {
            width: parent.width
            spacing: 6
            Repeater {
                model: actions.shortcuts
                delegate: Item {
                    id: tile
                    required property var modelData
                    width: (column.width - 6 * (actions.shortcuts.length - 1)) / actions.shortcuts.length
                    height: 34
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: actions.ink
                        opacity: tileMouse.pressed ? 0.16 : tileMouse.containsMouse ? 0.10 : 0.06
                        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                    }
                    Label { anchors.centerIn: parent; text: tile.modelData.label; role: Enums.TextRole.Bar; font.pixelSize: 11; color: actions.ink }
                    MouseArea { id: tileMouse; anchors.fill: parent; hoverEnabled: true; onClicked: actions.viewRequested(tile.modelData.view) }
                }
            }
        }
    }
}
