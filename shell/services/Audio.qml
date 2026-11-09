pragma Singleton
// Audio: sinks, sources, streams, volumes, mute.
// Owner: S3 (S5 extends for the Deck). Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

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
    // The service works (S3): the default sink and source are followed.
    readonly property bool available: false
    // description of the default source (the mic OSD)
    property string sourceName: ""
    // Under APTUS_TEST: an in-memory double instead of PipeWire (the real graph is never touched).
    readonly property bool testDouble: false

    // [{ id, name, description, isDefault, volume, muted }] (S5 fills the lists)
    property var sinks: []
    property var sources: []
    // application streams: [{ id, app, icon, volume, muted }]
    property var streams: []

    // Volume step for the hardware keys: direction ±1, fine = 1 % instead of audio.step (shows the OSD).
    function stepVolume(direction: int, fine: bool): void { Log.info("service.audio", "stepVolume: not available yet"); }
    function toggleMute(): void { Log.info("service.audio", "toggleMute: not available yet"); }
    function toggleMicMute(): void { Log.info("service.audio", "toggleMicMute: not available yet"); }
    function setVolume(volume: real): void { Log.info("service.audio", "setVolume: not available yet"); }
    function setMuted(muted: bool): void { Log.info("service.audio", "setMuted: not available yet"); }
    function setMicMuted(muted: bool): void { Log.info("service.audio", "setMicMuted: not available yet"); }
    function setDefaultSink(id: int): void { Log.info("service.audio", "setDefaultSink: not available yet"); }
    function setDefaultSource(id: int): void { Log.info("service.audio", "setDefaultSource: not available yet"); }
    function setStreamVolume(id: int, volume: real): void { Log.info("service.audio", "setStreamVolume: not available yet"); }
}
