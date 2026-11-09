// The media activity's compact look (surfaces/notch.md §4): an 18 px cover (radius 4); paused,
// the cover lies under a 40 % ink.faint wash. A still image, never an equaliser.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The MprisPlayer.
    property var player: null
    property bool paused: false

    // TODO(phase): the 18 px cover (radius 4; trackArtUrl, else the player's app icon on `raised`,
    //   notch.md §12), paused: 40 % ink.faint overlay.
}
