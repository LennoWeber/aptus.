pragma Singleton
// Audio: sinks, sources, streams, volumes, mute.
// Owner: S3 (S5 extends for the Deck). Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // default sink volume 0..1.5
    property real volume: 0
    property bool muted: false
    property bool micMuted: false
    // description of the default sink
    property string sinkName: ""
    // Pipewire bound
    property bool ready: false
}
