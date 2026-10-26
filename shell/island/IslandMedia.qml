import QtQuick
import qs.models
import qs.theme
import qs.components

// The music card in the opened island: cover, title, artist, progress and the three buttons.
Item {
    id: card

    property var mediaState  // MediaState
    property color ink
    property color inkSoft
    property color line
}
