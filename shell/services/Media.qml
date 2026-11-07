pragma Singleton
// Media: players, the active player rule (notch.md §5).
// Owner: S3. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    property var players: []
    // the active MprisPlayer or null
    property var active: null
}
