// AppIcon: An app icon from its desktop entry; fallback: raised rounded square with the first letter (03 §5).
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): IconImage from the icon theme with a letter fallback.

    property string icon: ""
    property string name: ""
    property real size: 20
}
