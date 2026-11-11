pragma ComponentBehavior: Bound
// The media card (surfaces/notch.md §5, 420 × 132): cover 88, title, artist · album, app icon 16
// + player name, the seekable progress (4 px, accent), elapsed / −remaining; previous,
// play/pause (36 round primary), next; shuffle and loop only when the player supports them.
import QtQuick
import Quickshell.Services.Mpris
import qs.core
import qs.services
import qs.components
import "../../core/js/format.js" as F

Item {
    id: root

    // Set by the card host (ActivityCard).
    property string monitorName: ""
    property var activity: null
    // The MprisPlayer.
    readonly property var player: activity ? activity.player : null
    // The card has the keyboard (opened by click).
    property bool pinned: false
    // The position while the pointer drags the progress bar (-1 = not dragging), seconds.
    property real _dragPosition: -1
    // The player's position: read when the card shows, the player or the track changes, after a
    // seek, and once a second while it plays (MPRIS sends no position updates).
    property real _position: 0
    function _readPosition(): void { _position = player ? player.position : 0; }
    onPlayerChanged: _readPosition()
    onVisibleChanged: if (visible) _readPosition()
    Component.onCompleted: _readPosition()
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPostTrackChanged(): void { root._readPosition(); }
        function onIsPlayingChanged(): void { root._readPosition(); }
    }

    // Found by the probe (phase 5):
    // The card's tokens, the track length (0 when the player has none), the position shown (the
    // drag's while seeking) and the art URL.
    readonly property var _c: Tokens.surfaces.card
    readonly property real _length: player && player.lengthSupported ? player.length : 0
    readonly property real _shownPos: _dragPosition >= 0 ? _dragPosition : _position
    readonly property string _art: player ? String(player.trackArtUrl || "") : ""

    Timer {
        interval: 1000
        repeat: true
        running: !!root.player && root.player.isPlaying && root.visible
        onTriggered: root._readPosition()
    }

    Item {
        id: cover
        width: root._c.mediaCoverSize
        height: width
        anchors.verticalCenter: parent.verticalCenter
        Thumb {
            anchors.fill: parent
            visible: root._art !== ""
            radius: root._c.mediaCoverRadius
            source: root._art
        }
        Rectangle {
            anchors.fill: parent
            visible: root._art === ""
            radius: root._c.mediaCoverRadius
            color: Tokens.raised
            AppIcon {
                anchors.centerIn: parent
                size: parent.width / 2
                icon: root.player ? String(root.player.desktopEntry || "") : ""
                name: root.player ? String(root.player.identity || "") : ""
            }
        }
    }
    Column {
        x: cover.width + Tokens.s5
        width: parent.width - x
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.s2
        Label {
            width: parent.width
            type: "title"
            elide: Text.ElideRight
            text: root.player ? (root.player.trackTitle || root.player.identity || "") : ""
        }
        Label {
            width: parent.width
            type: "body"
            ink: "meta"
            elide: Text.ElideRight
            visible: text !== ""
            text: root.player ? [root.player.trackArtist, root.player.trackAlbum].filter(s => !!s).join(" · ") : ""
        }
        Row {
            spacing: Tokens.s2
            AppIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: root._c.mediaAppIconSize
                icon: root.player ? String(root.player.desktopEntry || "") : ""
                name: root.player ? String(root.player.identity || "") : ""
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                type: "micro"
                ink: "meta"
                text: root.player ? String(root.player.identity || "") : ""
            }
        }
        // the seek bar
        Item {
            width: parent.width
            height: Tokens.s4
            visible: root._length > 0
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: root._c.mediaProgressHeight
                radius: height / 2
                color: Tokens.line
                Rectangle {
                    width: root._length > 0 ? parent.width * Math.min(1, root._shownPos / root._length) : 0
                    height: parent.height
                    radius: parent.radius
                    color: Tokens.accent
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: !!root.player && root.player.canSeek
                function _at(x: real): real { return Math.max(0, Math.min(1, x / width)) * root._length; }
                onPressed: m => root._dragPosition = _at(m.x)
                onPositionChanged: m => { if (pressed) root._dragPosition = _at(m.x); }
                onReleased: {
                    Media.seek(root._dragPosition);
                    root._position = root._dragPosition;
                    root._dragPosition = -1;
                }
                onCanceled: root._dragPosition = -1
            }
        }
        Item {
            width: parent.width
            height: controls.height
            Label {
                anchors.verticalCenter: parent.verticalCenter
                type: "micro"
                ink: "meta"
                tabular: true
                visible: root._length > 0
                text: F.clockDuration(root._shownPos) + " / −" + F.clockDuration(Math.max(0, root._length - root._shownPos))
            }
            Row {
                id: controls
                anchors.right: parent.right
                spacing: Tokens.s2
                IconButton {
                    visible: !!root.player && root.player.shuffleSupported
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "shuffle"
                    tooltip: "Shuffle"
                    on: !!root.player && root.player.shuffle
                    onClicked: Media.toggleShuffle()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "skip_previous"
                    tooltip: "Previous"
                    disabledReason: root.player && root.player.canGoPrevious ? "" : "The player cannot go back"
                    onClicked: Media.previous()
                }
                // the 36 px round primary button (notch.md §5)
                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root._c.mediaPrimaryButtonSize
                    height: root._c.mediaPrimaryButtonSize
                    variant: "primary"
                    round: true
                    glyph: root.player && root.player.isPlaying ? "pause" : "play_arrow"
                    tooltip: root.player && root.player.isPlaying ? "Pause" : "Play"
                    onClicked: Media.toggle()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "skip_next"
                    tooltip: "Next"
                    disabledReason: root.player && root.player.canGoNext ? "" : "The player cannot skip"
                    onClicked: Media.next()
                }
                IconButton {
                    visible: !!root.player && root.player.loopSupported
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: root.player && root.player.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                    tooltip: "Repeat"
                    on: !!root.player && root.player.loopState !== MprisLoopState.None
                    onClicked: Media.cycleLoop()
                }
            }
        }
    }
}
