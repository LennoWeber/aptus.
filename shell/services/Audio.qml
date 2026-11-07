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

    // Volume step for the hardware keys: direction ±1, fine = 1 % instead of audio.step (shows the OSD).
    function stepVolume(direction: int, fine: bool): void { throw new Error("Audio.stepVolume: not implemented"); }
    function toggleMute(): void { throw new Error("Audio.toggleMute: not implemented"); }
    function toggleMicMute(): void { throw new Error("Audio.toggleMicMute: not implemented"); }
}
