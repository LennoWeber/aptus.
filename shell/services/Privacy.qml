pragma Singleton
// Privacy: mic, camera, screencast in use.
// Owner: S3. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // TODO(phase): outside Paths.test, a PwObjectTracker over Pipewire.nodes (streams and video
    //   sources; a LazyLoader that is never active under the test) → _rebuild on every node or
    //   state change, within bar.privacyAppearMaxMs. Under the test both stay empty.
    // apps using the microphone
    property var mic: []
    // apps using a camera
    property var camera: []
    // TODO(phase): Hypr.screencast.
    property bool screencast: false
    // The service works (S3); under APTUS_TEST only the screencast part (no PipeWire).
    // TODO(phase): true.
    readonly property bool available: false

    // Rebuild mic and camera from the PipeWire nodes (status.js privacy); never under Paths.test.
    function _rebuild(): void { throw new Error("not implemented"); }
}
