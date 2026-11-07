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

    // [{ id, name, description, isDefault, volume, muted }] (S5 fills the lists)
    property var sinks: []
    property var sources: []
    // application streams: [{ id, app, icon, volume, muted }]
    property var streams: []

    // Volume step for the hardware keys: direction ±1, fine = 1 % instead of audio.step (shows the OSD).
    function stepVolume(direction: int, fine: bool): void { throw new Error("Audio.stepVolume: not implemented"); }
    function toggleMute(): void { throw new Error("Audio.toggleMute: not implemented"); }
    function toggleMicMute(): void { throw new Error("Audio.toggleMicMute: not implemented"); }
    function setVolume(volume: real): void { throw new Error("Audio.setVolume: not implemented"); }
    function setMuted(muted: bool): void { throw new Error("Audio.setMuted: not implemented"); }
    function setMicMuted(muted: bool): void { throw new Error("Audio.setMicMuted: not implemented"); }
    function setDefaultSink(id: int): void { throw new Error("Audio.setDefaultSink: not implemented"); }
    function setDefaultSource(id: int): void { throw new Error("Audio.setDefaultSource: not implemented"); }
    function setStreamVolume(id: int, volume: real): void { throw new Error("Audio.setStreamVolume: not implemented"); }
}
