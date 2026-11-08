// AppIcon: An app icon from its desktop entry; fallback: raised rounded square with the first letter (03 §5).
// `icon` is an icon-theme name, an absolute path or a URL (tray items give image:// URLs).
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.core

Item {
    id: root

    property string icon: ""
    property string name: ""
    property real size: Tokens.appIconRow

    readonly property string _source: icon === "" ? ""
        : icon.charAt(0) === "/" ? Paths.url(icon)
        : icon.indexOf("://") > 0 ? icon
        : Quickshell.iconPath(icon, true)
    readonly property bool _ready: image.status === Image.Ready

    implicitWidth: size
    implicitHeight: size
    Accessible.role: Accessible.Graphic
    Accessible.name: name

    IconImage {
        id: image
        anchors.fill: parent
        implicitSize: root.size
        source: root._source
        visible: root._ready
    }
    Rectangle {
        anchors.fill: parent
        visible: !root._ready
        radius: root.size / 4
        color: Tokens.raised

        Text {
            anchors.centerIn: parent
            text: (root.name !== "" ? root.name : root.icon).charAt(0).toUpperCase()
            color: Tokens.inkSec
            font.family: Tokens.fontUi
            font.pixelSize: root.size / 2
            font.weight: Tokens.font("bodyStrong").weight
        }
    }
}
