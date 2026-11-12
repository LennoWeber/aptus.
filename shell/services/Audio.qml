pragma Singleton
pragma ComponentBehavior: Bound
// Audio: sinks, sources, streams, volumes, mute.
// Owner: S3 (S5 extends for the Deck).
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.core
import "js/levels.js" as L

Singleton {
    id: root

    // default sink volume 0..1.5
    readonly property real volume: _b ? _b.volume : 0
    readonly property bool muted: _b ? _b.muted : false
    readonly property bool micMuted: _b ? _b.micMuted : false
    // description of the default sink
    readonly property string sinkName: _b ? _b.sinkName : ""
    // Pipewire bound (or the double)
    readonly property bool ready: _b ? _b.ready : false
    // The service works (S3): the default sink and source are followed.
    readonly property bool available: ready
    // description of the default source (the mic OSD)
    readonly property string sourceName: _b ? _b.sourceName : ""
    // The backend, chosen once: PipeWire, or under APTUS_TEST the in-memory double (both have
    // the fields above and the three setters).
    readonly property var _b: testDouble ? fake : backend.item
    // Under APTUS_TEST: an in-memory double instead of PipeWire (the real graph is never touched).
    readonly property bool testDouble: Paths.test
    // The sink and source names of the last volume / mic OSD (the next OSD after a change names
    // the new device, notch.md §8).
    property string _osdSink: ""
    property string _osdSource: ""

    // [{ id, name, description, isDefault, volume, muted }] (S5 fills the lists)
    property var sinks: []
    property var sources: []
    // application streams: [{ id, app, icon, volume, muted }]
    property var streams: []

    // The volume's maximum in percent: osd.volumeBoostMax with audio.allowBoost, else osd.volumeMax.
    readonly property int _maxPercent: Config.get("audio.allowBoost") ? Tokens.surfaces.osd.volumeBoostMax
                                                                     : Tokens.surfaces.osd.volumeMax
    // Volume step for the hardware keys: direction ±1, fine = 1 % instead of audio.step (shows the OSD).
    function stepVolume(direction: int, fine: bool): void {
        if (!ready) return;
        const stepPct = fine ? 1 : (Config.get("audio.step") || 5);
        const next = L.step(volume * 100, direction, stepPct, 0, _maxPercent);
        if (Math.abs(next - volume * 100) > 1e-6) setVolume(next / 100);     // above the maximum: unchanged
        _osd("volume");
    }
    function toggleMute(): void { if (!ready) return; setMuted(!muted); _osd("volume"); }
    function toggleMicMute(): void { if (!ready) return; setMicMuted(!micMuted); _osd("mic"); }
    function setVolume(v: real): void {
        if (_refused("setVolume")) return;
        if (_b) _b.setVolume(Math.max(0, Math.min(_maxPercent / 100, v)));
    }
    function setMuted(m: bool): void {
        if (_refused("setMuted")) return;
        if (_b) _b.setMuted(m);
    }
    function setMicMuted(m: bool): void {
        if (_refused("setMicMuted")) return;
        if (_b) _b.setMicMuted(m);
    }
    function setDefaultSink(id: int): void { if (_refused("setDefaultSink")) return; Log.info("service.audio", "setDefaultSink: not available yet"); }
    function setDefaultSource(id: int): void { if (_refused("setDefaultSource")) return; Log.info("service.audio", "setDefaultSource: not available yet"); }
    function setStreamVolume(id: int, volume: real): void { if (_refused("setStreamVolume")) return; Log.info("service.audio", "setStreamVolume: not available yet"); }

    // Post the OSD of a kind ("volume" | "mic") on the active monitor, unless the Deck is open
    // there (its slider moves instead, notch.md §8; levels.js deckReplaces).
    function _osd(kind: string): void {
        const mon = SurfaceManager.activeMonitor;
        const m = SurfaceManager.monitorState(mon);
        if (m && m.deck && L.deckReplaces(kind)) return;
        let payload;
        if (kind === "mic") {
            const dev = sourceName !== _osdSource && _osdSource !== "" ? sourceName : "";
            _osdSource = sourceName;
            payload = L.micOsd(micMuted, dev);
        } else {
            const dev = sinkName !== _osdSink && _osdSink !== "" ? sinkName : "";
            _osdSink = sinkName;
            payload = L.volumeOsd(volume, muted, _maxPercent, dev);
        }
        SurfaceManager.post("osd", payload, 0, mon, kind);
    }

    // Invariant (phase 6): a test shell never writes the real PipeWire graph. Under APTUS_TEST
    // every write goes to the double, and the PipeWire backend must not exist: a write while it
    // does is refused and logged.
    function _refused(what: string): bool {
        if (!Paths.test || !backend.item) return false;
        Log.error("service.audio", what + " refused in a test (PipeWire backend loaded)");
        return true;
    }
    // The backend appearing under APTUS_TEST is a broken invariant on its own (the LazyLoader is
    // never active under the double), logged once when it happens.
    Connections {
        target: backend
        function onItemChanged(): void { if (Paths.test && backend.item) Log.error("service.audio", "PipeWire backend loaded in a test"); }
    }

    // The in-memory double (tests): the real graph is never touched.
    QtObject {
        id: fake
        readonly property bool ready: true
        property real volume: 0.5
        property bool muted: false
        property bool micMuted: false
        property string sinkName: "Test speakers"
        property string sourceName: "Test microphone"
        function setVolume(v: real): void { volume = v; }
        function setMuted(m: bool): void { muted = m; }
        function setMicMuted(m: bool): void { micMuted = m; }
    }
    // The PipeWire backend, never loaded under the test.
    LazyLoader {
        id: backend
        active: !root.testDouble
        component: QtObject {
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property var source: Pipewire.defaultAudioSource
            readonly property bool ready: Pipewire.ready && !!sink && !!sink.audio
            readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
            readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
            readonly property bool micMuted: source && source.audio ? source.audio.muted : false
            readonly property string sinkName: sink ? (sink.description || sink.nickname || sink.name) : ""
            readonly property string sourceName: source ? (source.description || source.nickname || source.name) : ""
            function setVolume(v: real): void { if (sink && sink.audio) sink.audio.volume = v; }
            function setMuted(m: bool): void { if (sink && sink.audio) sink.audio.muted = m; }
            function setMicMuted(m: bool): void { if (source && source.audio) source.audio.muted = m; }
            property PwObjectTracker tracker: PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
        }
    }
}
