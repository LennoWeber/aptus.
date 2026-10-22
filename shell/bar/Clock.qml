import QtQuick
import Quickshell
import qs.models
import qs.theme
import qs.components

// Clock and date in the bar.
Item {
    id: clock

    property string format: "24h"  // 24h | 12h
    property bool showSeconds
    property bool showDate: true
    property var now: sysClock.date  // Date
    signal clicked()

    SystemClock {
        id: sysClock
        precision: clock.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    // English names, as the whole UI is English; the time uses the user's 24 h or 12 h choice.
    readonly property var english: Qt.locale("en_GB")
    readonly property string dateText: english.toString(now, "ddd d MMM")
    readonly property string timeText: english.toString(now, format === "12h" ? (showSeconds ? "h:mm:ss AP" : "h:mm AP") : (showSeconds ? "HH:mm:ss" : "HH:mm"))

    implicitWidth: item.implicitWidth
    implicitHeight: Tokens.barHeight

    BarItem {
        id: item
        anchors.fill: parent
        onClicked: clock.clicked()

        Label {
            visible: clock.showDate
            anchors.verticalCenter: parent.verticalCenter
            text: clock.dateText
            role: Enums.TextRole.Bar
            // TODO(phase 7, Bild-Theming): secondary bar text uses Tokens.barInkSoft, see Bar.qml.
            color: Tokens.inkSoft
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: clock.timeText
            role: Enums.TextRole.Bar
            font.weight: Font.Medium
        }
    }
}
