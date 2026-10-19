import QtQuick
import qs.theme
import qs.components

// Large clock and date for lockscreen and greeter.
Item {
    id: block

    property bool use24h: true
    property var now: new Date()  // Date
    readonly property var english: Qt.locale("en_GB")

    implicitWidth: Math.max(time.implicitWidth, date.implicitWidth)
    implicitHeight: time.implicitHeight + date.implicitHeight + 4

    Text {
        id: time
        anchors.horizontalCenter: parent.horizontalCenter
        text: block.english.toString(block.now, block.use24h ? "HH:mm" : "h:mm")
        font.family: Tokens.fontUi
        font.pixelSize: 132
        font.weight: Font.Light
        color: Tokens.ink
        renderType: Text.NativeRendering
    }
    Label {
        id: date
        anchors { horizontalCenter: parent.horizontalCenter; top: time.bottom; topMargin: -6 }
        text: block.english.toString(block.now, "dddd, d MMMM")
        font.pixelSize: 20
        color: Tokens.inkSoft
    }
}
