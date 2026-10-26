import QtQuick
import qs.theme
import qs.components

// A slider drawn in the island's colours (SliderControl uses fixed Tokens colours): icon, thin track, round handle.
Item {
    id: slider

    property real value
    property color ink
    property color line
    property string iconName
    signal moved(real value)
    signal iconClicked()
}
