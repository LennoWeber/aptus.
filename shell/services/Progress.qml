pragma Singleton
// Progress: progress activities (downloads, copies) from notification hints.
// Owner: S3. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): until S3 fills this service, each action method logs "not available yet"
    //   (category service.<name>) instead of throwing (phase-1 decision 6).

    // [{ id, name, fraction: 0..1 | -1 (unknown), rate: string, remaining: string, cancellable: bool, source }]
    property var items: []
    function cancel(id: string): void { throw new Error("Progress.cancel: not implemented"); }
}
