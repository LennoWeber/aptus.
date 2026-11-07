// The notch: clock at rest, compact activities, toasts, OSD, events, cards; hosts the notch modes from NotchModes (surfaces/notch.md).
// Owner: S3. Stub until its stage fills it.
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    property MonitorState monitor
    // 0 → 1 during the session intro (M-01); 1 otherwise.
    property real introProgress: 1
    // Notch-mode id → Component (from qs.registry NotchModes, passed in by MonitorShell so the
    // notch never imports the registry).
    property var modeComponents: ({})
    // The notch's part of the frame shape.
    readonly property BulgeSpec bulge: BulgeSpec {}
    // Width the notch occupies inside the bar at rest (the bar keeps its zones clear of it).
    readonly property real restWidth: 0
    // The item whose area takes pointer input (bar band part plus the bulge), for the input mask.
    readonly property Item maskItem: null
}
