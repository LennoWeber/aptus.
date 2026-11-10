// The media card (surfaces/notch.md §5, 420 × 132): cover 88, title, artist · album, app icon 16
// + player name, the seekable progress (4 px, accent), elapsed / −remaining; previous,
// play/pause (36 round primary), next; shuffle and loop only when the player supports them.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // Set by the card host (ActivityCard).
    property string monitorName: ""
    property var activity: null
    // The MprisPlayer.
    property var player: null
    // The card has the keyboard (opened by click).
    property bool pinned: false

    // The position while the pointer drags the progress bar (-1 = not dragging), seconds.
    property real _dragPosition: -1
    // The player's position, re-read once a second while the card is shown and playing.
    property real _position: 0

    // TODO(phase): cover 88 (the app icon on `raised` without art), title (the player's name
    //   without metadata, notch.md §12), artist · album, app icon + identity, the seek bar (drag →
    //   _dragPosition, release → Media.seek), 0:42 / −2:18 (clockDuration), previous / play-pause
    //   (36, primary) / next, shuffle and loop when supported (Media.toggleShuffle/cycleLoop); a
    //   1 s Timer re-reads position while shown and playing.

    // Found by the probe (phase 5):
    // The card's tokens, the track length (0 when the player has none), the position shown (the
    // drag's while seeking) and the art URL.
    // TODO(phase): Tokens.surfaces.card; player.length if lengthSupported; _dragPosition ≥ 0 ?
    //   _dragPosition : _position; String(player.trackArtUrl).
    readonly property var _c: ({})
    readonly property real _length: 0
    readonly property real _shownPos: 0
    readonly property string _art: ""
    // TODO(phase): play/pause is the round primary Button of card.mediaPrimaryButtonSize
    //   (notch.md §5), not an IconButton.
}
