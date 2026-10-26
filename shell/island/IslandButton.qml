import QtQuick
import qs.theme
import qs.components

// A round icon button of the island (touch size 36).
Item {
    id: button

    property string kind
    property color color
    property int size: 36
    signal clicked()
}
