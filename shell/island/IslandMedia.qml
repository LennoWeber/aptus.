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
    implicitHeight: 64

    Rectangle {
        id: cover
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: 56
        height: 56
        radius: 8
        color: card.line
        clip: true

        Image {
            anchors.fill: parent
            source: card.mediaState ? card.mediaState.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Column {
        anchors { left: cover.right; leftMargin: 12; right: buttons.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 2
        Label {
            width: parent.width
            text: card.mediaState ? card.mediaState.title : ""
            color: card.ink
            elide: Text.ElideRight
            font.weight: Font.DemiBold
        }
        Label {
            width: parent.width
            text: card.mediaState ? card.mediaState.artist : ""
            elide: Text.ElideRight
            color: card.inkSoft
            role: Enums.TextRole.Bar
        }
        Rectangle {
            width: parent.width
            height: 2
            radius: 1
            color: card.line
            Rectangle {
                width: card.mediaState && card.mediaState.lengthSec > 0 ? parent.width * Math.min(1, card.mediaState.positionSec / card.mediaState.lengthSec) : 0
                height: 2
                radius: 1
                color: card.ink
            }
        }
    }

    Row {
        id: buttons
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        IslandButton { kind: "prev"; color: card.ink; onClicked: if (card.mediaState) card.mediaState.previous() }
        IslandButton { kind: card.mediaState && card.mediaState.playing ? "pause" : "play"; color: card.ink; onClicked: if (card.mediaState) card.mediaState.playPause() }
        IslandButton { kind: "next"; color: card.ink; onClicked: if (card.mediaState) card.mediaState.next() }
    }
}
