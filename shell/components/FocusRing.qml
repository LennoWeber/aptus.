// FocusRing: The keyboard focus ring (03 §6.3): 2 px accent, 2 px outside the target, radius + 2; only after keyboard navigation.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): 2 px accent ring outside the target's radius, only for keyboard focus.

    property Item target: null
    property real targetRadius: 0
    property bool shown: false
}
