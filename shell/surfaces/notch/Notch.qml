// The notch: clock at rest, compact activities, toasts, OSD, events, cards; hosts the notch modes from NotchModes (surfaces/notch.md).
// Owner: S3. Stub until its stage fills it.
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // TODO(S3): register the open mode's back() with SurfaceManager.registerBack(monitor.name, mode, fn)
    //   and unregister when it leaves (the host knows the surface id; the base type does not).

    property MonitorState monitor
    // 0 → 1 during the session intro (M-01); 1 otherwise.
    property real introProgress: 1
    // Notch-mode id → Component (from qs.registry NotchModes, passed in by MonitorShell so the
    // notch never imports the registry).
    property var modeComponents: ({})
    // Activity id → Component and card id → Component (qs.registry Activities, via MonitorShell).
    property var activityComponents: ({})
    property var cardComponents: ({})
    // The notch's part of the frame shape.
    readonly property BulgeSpec bulge: BulgeSpec {}
    // The rest clock's rectangle in monitor coordinates (M-20 hand-off to Today).
    readonly property rect clockRect: Qt.rect(0, 0, 0, 0)
    // Width the notch occupies inside the bar at rest (the bar keeps its zones clear of it).
    readonly property real restWidth: 0
    // The item whose area takes pointer input (bar band part plus the bulge), for the input mask.
    readonly property Item maskItem: null
}
