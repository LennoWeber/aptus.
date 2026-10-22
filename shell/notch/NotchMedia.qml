import QtQuick
import qs.models
import qs.theme
import qs.components

// The music card in the open notch: cover, title, artist and the three buttons.
Item {
    id: card

    property var mediaState  // MediaState
    implicitHeight: 64

    Rectangle {
        id: cover
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: 56
        height: 56
        radius: 8
        color: Tokens.surfaceAlt
        border.width: 1
        border.color: Tokens.line
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
            elide: Text.ElideRight
            font.weight: Font.DemiBold
        }
        Label {
            width: parent.width
            text: card.mediaState ? card.mediaState.artist : ""
            elide: Text.ElideRight
            color: Tokens.inkSoft
            role: Enums.TextRole.Bar
        }
        Rectangle {
            width: parent.width
            height: 2
            radius: 1
            color: Tokens.line
            Rectangle {
                width: card.mediaState && card.mediaState.lengthSec > 0 ? parent.width * Math.min(1, card.mediaState.positionSec / card.mediaState.lengthSec) : 0
                height: 2
                radius: 1
                color: Tokens.ink
            }
        }
    }

    Row {
        id: buttons
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        NotchButton { kind: "prev"; onClicked: if (card.mediaState) card.mediaState.previous() }
        NotchButton { kind: card.mediaState && card.mediaState.playing ? "pause" : "play"; onClicked: if (card.mediaState) card.mediaState.playPause() }
        NotchButton { kind: "next"; onClicked: if (card.mediaState) card.mediaState.next() }
    }
}
