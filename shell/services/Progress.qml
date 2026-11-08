pragma Singleton
// Progress: progress activities (downloads, copies) from notification hints.
// Owner: S3. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // [{ id, name, fraction: 0..1 | -1 (unknown), rate: string, remaining: string, cancellable: bool, source }]
    property var items: []
    function cancel(id: string): void { Log.info("service.progress", "cancel: not available yet"); }
}
