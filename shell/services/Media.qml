pragma Singleton
// Media: players, the active player rule (notch.md §5).
// Owner: S3. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): until S3 fills this service, each action method logs "not available yet"
    //   (category service.<name>) instead of throwing (phase-1 decision 6).

    property var players: []
    // the active MprisPlayer or null
    property var active: null

    // The active player (05 §7 rule): play/pause, next, previous.
    function toggle(): void { throw new Error("Media.toggle: not implemented"); }
    function next(): void { throw new Error("Media.next: not implemented"); }
    function previous(): void { throw new Error("Media.previous: not implemented"); }
}
