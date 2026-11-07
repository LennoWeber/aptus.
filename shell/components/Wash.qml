// Wash: The state layer (03 §2.3): ink.main over the ground at hover / current / pressed amounts.
import QtQuick
import qs.core

Rectangle {
    id: root

    property bool hovered: false
    property bool current: false
    property bool pressed: false
    // accentWash instead of the ink washes ("on" tiles).
    property bool on: false
}
