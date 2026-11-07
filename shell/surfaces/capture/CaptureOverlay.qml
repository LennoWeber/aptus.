// The capture overlay: frozen frame, selection, colour picker (surfaces/capture.md).
// Owner: S9. Stub until its stage fills it.
import QtQuick
import qs.core

Item {
    id: root

    property MonitorState monitor
    property bool active: false
    // M-23: the selection in monitor coordinates (the thumbnail flies from here to the notch;
    // the capture card toast carries it as payload.flyFrom).
    readonly property rect selection: Qt.rect(0, 0, 0, 0)
}
