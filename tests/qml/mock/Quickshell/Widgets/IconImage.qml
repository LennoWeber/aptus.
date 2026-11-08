import QtQuick
// Test double of Quickshell.Widgets IconImage: a square, aspect-preserving Image.
Item {
    id: root

    property alias source: image.source
    property alias status: image.status
    property real implicitSize: 0

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    Image {
        id: image
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.min(root.width, root.height)
        sourceSize.height: Math.min(root.width, root.height)
    }
}
