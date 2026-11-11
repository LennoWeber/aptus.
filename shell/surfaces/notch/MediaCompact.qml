pragma ComponentBehavior: Bound
// The media activity's compact look (surfaces/notch.md §4): an 18 px cover (radius 4); paused,
// the cover lies under a 40 % ink.faint wash. A still image, never an equaliser.
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // Set by the slot (the activity object, MediaActivity).
    property var activity: null
    property string monitorName: ""
    // The MprisPlayer.
    readonly property var player: activity ? activity.player : null
    readonly property bool paused: activity ? activity.paused : false

    // The cover's size (notch.compactLeftSlotCoverSize) and the art URL.
    readonly property real _size: Tokens.surfaces.notch.compactLeftSlotCoverSize
    readonly property string _art: player ? String(player.trackArtUrl || "") : ""
    implicitWidth: _size
    implicitHeight: _size

    Thumb {
        anchors.fill: parent
        visible: root._art !== ""
        radius: Tokens.surfaces.notch.compactCoverRadius
        source: root._art
    }
    Rectangle {
        anchors.fill: parent
        visible: root._art === ""
        radius: Tokens.surfaces.notch.compactCoverRadius
        color: Tokens.raised
        AppIcon {
            anchors.centerIn: parent
            size: root._size - 2 * Tokens.s1
            icon: root.player ? String(root.player.desktopEntry || "") : ""
            name: root.player ? String(root.player.identity || "") : ""
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: root.paused
        radius: Tokens.surfaces.notch.compactCoverRadius
        color: Tokens.alpha(Tokens.inkFaint, Tokens.surfaces.notch.compactPausedCoverAlpha)
    }
}
