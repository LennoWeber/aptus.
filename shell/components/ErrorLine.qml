// ErrorLine: the error state of 03 §8: one ink.sec line and a plain Retry button.
import QtQuick
import qs.core

Item {
    id: root

    // What happened and what to do ("Could not reach Open-Meteo. Check the connection.").
    property string text: ""
    // Show the Retry button.
    property bool retry: true
    signal retryRequested()

    implicitWidth: line.implicitWidth + (retry ? Tokens.s5 + button.implicitWidth : 0)
    implicitHeight: Math.max(line.implicitHeight, retry ? button.implicitHeight : 0)

    Label {
        id: line
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.width - (root.retry ? Tokens.s5 + button.implicitWidth : 0))
        text: root.text
        ink: "sec"
    }
    Button {
        id: button
        anchors.left: line.right
        anchors.leftMargin: Tokens.s5
        anchors.verticalCenter: parent.verticalCenter
        visible: root.retry
        text: "Retry"
        variant: "plain"
        onClicked: root.retryRequested()
    }
}
