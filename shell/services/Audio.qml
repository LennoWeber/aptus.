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
    // TODO(phase): true with the double, or once the PipeWire backend is ready.
    readonly property bool available: false
    // description of the default source (the mic OSD)
    property string sourceName: ""
    // Under APTUS_TEST: an in-memory double instead of PipeWire (the real graph is never touched).
    // TODO(phase): Paths.test. The PipeWire backend (default sink/source, PwObjectTracker) is an
    //   inline component behind a LazyLoader that is never active under the double, so a test
    //   shell makes no PipeWire connection at all; volume/muted/micMuted/names follow it.
    readonly property bool testDouble: false
    // The sink and source names of the last volume / mic OSD (the next OSD after a change names
    // the new device, notch.md §8).
    property string _osdSink: ""
    property string _osdSource: ""

    // [{ id, name, description, isDefault, volume, muted }] (S5 fills the lists)
    property var sinks: []
    property var sources: []
    // application streams: [{ id, app, icon, volume, muted }]
    property var streams: []

    // Volume step for the hardware keys: direction ±1, fine = 1 % instead of audio.step (shows the OSD).
    // TODO(phase): levels.js step on the percent scale (max osd.volumeBoostMax with
    //   audio.allowBoost, else osd.volumeMax), setVolume, then _osd("volume").
    function stepVolume(direction: int, fine: bool): void { Log.info("service.audio", "stepVolume: not available yet"); }
    // TODO(phase): setMuted(!muted) + _osd("volume"); setMicMuted(!micMuted) + _osd("mic").
    function toggleMute(): void { Log.info("service.audio", "toggleMute: not available yet"); }
    function toggleMicMute(): void { Log.info("service.audio", "toggleMicMute: not available yet"); }
    // TODO(phase): write the default sink/source (backend node audio.volume / .muted) or the
    //   double's own properties; never anything else.
    function setVolume(volume: real): void { if (_refused("setVolume")) return; Log.info("service.audio", "setVolume: not available yet"); }
    function setMuted(muted: bool): void { if (_refused("setMuted")) return; Log.info("service.audio", "setMuted: not available yet"); }
    function setMicMuted(muted: bool): void { if (_refused("setMicMuted")) return; Log.info("service.audio", "setMicMuted: not available yet"); }
    function setDefaultSink(id: int): void { if (_refused("setDefaultSink")) return; Log.info("service.audio", "setDefaultSink: not available yet"); }
    function setDefaultSource(id: int): void { if (_refused("setDefaultSource")) return; Log.info("service.audio", "setDefaultSource: not available yet"); }
    function setStreamVolume(id: int, volume: real): void { if (_refused("setStreamVolume")) return; Log.info("service.audio", "setStreamVolume: not available yet"); }
    // Invariant (phase 6): a test shell never writes the real PipeWire graph. Under APTUS_TEST
    // every write goes to the double, and the PipeWire backend must not exist: a write while it
    // does (or without the double) is refused and logged.
    function _refused(what: string): bool {
        if (!Paths.test || (testDouble && !_b)) return false;
        Log.error("service.audio", what + " refused in a test (" + (_b ? "PipeWire backend loaded" : "no double") + ")");
        return true;
    }
    // The backend appearing under APTUS_TEST is a broken invariant on its own (the LazyLoader is
    // never active under the double), logged once when it happens.
    on_BChanged: if (Paths.test && _b) Log.error("service.audio", "PipeWire backend loaded in a test");

    // Post the OSD of a kind ("volume" | "mic") on the active monitor, unless the Deck is open
    // there (its slider moves instead, notch.md §8; levels.js deckReplaces).
    function _osd(kind: string): void { throw new Error("not implemented"); }

    // Found by the probe (phase 5):
    // The PipeWire backend object (null under the double; untyped, the Loader's item).
    // TODO(phase): backend.item.
    readonly property var _b: null
}
