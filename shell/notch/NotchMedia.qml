import QtQuick
import qs.models
import qs.theme
import qs.components

// The player in the opened notch: cover, title and artist, a thin progress line and previous, play/pause, next.
Item {
    id: player

    property var mediaState         // MediaState
    property string look: "light"
    property bool available
    property real progress          // 0..1, from the state's position and length
}
