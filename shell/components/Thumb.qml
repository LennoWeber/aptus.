// Thumb: A rounded image thumbnail (wallpapers, screenshots, covers).
import QtQuick
import qs.core

Item {
    id: root

    property string source: ""
    property real radius: 10
    property bool selected: false
}
