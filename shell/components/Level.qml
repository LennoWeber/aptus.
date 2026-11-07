// Level: The OSD level bar (03 §9): 6 px, radius 3, accent fill, snappy spring; the part over 1 in warn.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): a horizontal level bar (battery, volume OSD).

    // 0..max
    property real value: 0
    property real max: 1
}
