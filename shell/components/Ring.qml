// Ring: Progress ring (03 §9): 2 px line track, 2 px arc, round caps.
import QtQuick
import QtQuick.Shapes
import qs.core

Item {
    id: root

    // 0..1
    property real progress: 0
    property real thickness: 2
    property color colour
}
