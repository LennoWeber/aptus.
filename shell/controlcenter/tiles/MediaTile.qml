import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the MediaTile.
Item {
    id: tile

    property bool expanded
    property var mediaState

    readonly property bool has: mediaState ? mediaState.available : false

    function clock(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    // Round transport buttons built from the drawn symbols.
    component Transport: Item {
        id: btn
        property string kind
        property int size: 40
        signal clicked()
        width: size
        height: size
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Tokens.surfaceAlt
            opacity: area.pressed ? 1 : area.containsMouse ? 0.7 : 0
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
        }
        StatusGlyph { anchors.centerIn: parent; kind: btn.kind; width: 18; height: 18; color: Tokens.ink }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: btn.clicked() }
    }

    // Compact: small cover, title, artist, buttons.
    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Rectangle {
            id: smallCover
            width: 56
            height: 56
            radius: 10
            color: Tokens.surfaceAlt
            clip: true
            Image {
                anchors.fill: parent
                source: tile.mediaState ? tile.mediaState.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        Column {
            anchors { left: smallCover.right; leftMargin: 12; right: parent.right; top: parent.top }
            Label {
                width: parent.width
                elide: Text.ElideRight
                text: tile.has ? tile.mediaState.title : "Nothing playing"
                font.weight: Font.Medium
            }
            Label {
                width: parent.width
                elide: Text.ElideRight
                text: tile.has ? tile.mediaState.artist : ""
                color: Tokens.inkSoft
            }
        }
        Row {
            anchors { left: smallCover.right; leftMargin: 8; bottom: parent.bottom }
            visible: tile.has
            Transport { kind: "prev"; size: 36; onClicked: tile.mediaState.previous() }
            Transport { kind: tile.mediaState && tile.mediaState.playing ? "pause" : "play"; size: 36; onClicked: tile.mediaState.playPause() }
            Transport { kind: "next"; size: 36; onClicked: tile.mediaState.next() }
        }
    }

    // Expanded: big cover, details, seek bar.
    Item {
        anchors.fill: parent
        visible: tile.expanded

        Rectangle {
            id: bigCover
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: Math.min(parent.height - 20, 260)
            height: width
            radius: 14
            color: Tokens.surfaceAlt
            clip: true
            Image {
                anchors.fill: parent
                source: tile.mediaState ? tile.mediaState.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        Column {
            anchors { left: bigCover.right; leftMargin: 28; right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 4
            Label {
                width: parent.width
                elide: Text.ElideRight
                text: tile.has ? tile.mediaState.title : "Nothing playing"
                role: Enums.TextRole.Title
            }
            Label {
                width: parent.width
                elide: Text.ElideRight
                text: tile.has ? tile.mediaState.artist : ""
                color: Tokens.inkSoft
            }
            Label {
                width: parent.width
                elide: Text.ElideRight
                text: tile.has ? tile.mediaState.album + (tile.mediaState.playerName ? "  ·  " + tile.mediaState.playerName : "") : ""
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }
            Item { width: 1; height: 14 }
            SliderControl {
                visible: tile.has && tile.mediaState.lengthSec > 0
                width: parent.width
                from: 0
                to: Math.max(1, tile.mediaState ? tile.mediaState.lengthSec : 1)
                value: tile.mediaState ? tile.mediaState.positionSec : 0
                onMoved: v => tile.mediaState.seek(v)
            }
            Item {
                visible: tile.has && tile.mediaState.lengthSec > 0
                width: parent.width
                height: 18
                Label { text: tile.clock(tile.mediaState ? tile.mediaState.positionSec : 0); role: Enums.TextRole.Bar; color: Tokens.inkFaint; tabularNumbers: true }
                Label { anchors.right: parent.right; text: tile.clock(tile.mediaState ? tile.mediaState.lengthSec : 0); role: Enums.TextRole.Bar; color: Tokens.inkFaint; tabularNumbers: true }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: tile.has
                spacing: 8
                Transport { kind: "prev"; size: 48; onClicked: tile.mediaState.previous() }
                Transport { kind: tile.mediaState && tile.mediaState.playing ? "pause" : "play"; size: 48; onClicked: tile.mediaState.playPause() }
                Transport { kind: "next"; size: 48; onClicked: tile.mediaState.next() }
            }
        }
    }
}
