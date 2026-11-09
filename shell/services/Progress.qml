pragma Singleton
// Progress: progress activities (downloads, copies) from notification hints.
// Owner: S3. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // [{ id, name, fraction: 0..1 | -1 (unknown), rate: string, remaining: string, cancellable: bool, source }]
    // id "n:<notification id>" for items from a notification's progress hint (source "notification").
    property var items: []
    // The service works (S3).
    readonly property bool available: false
    function cancel(id: string): void { Log.info("service.progress", "cancel: not available yet"); }
}
