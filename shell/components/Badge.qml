// Badge: Badge (03 §9): a 6 px dot, or a pill with a count.
import QtQuick
import qs.core

Item {
    id: root

    // -1: a dot; ≥ 0: a count pill.
    property int count: -1
    property color colour
}
