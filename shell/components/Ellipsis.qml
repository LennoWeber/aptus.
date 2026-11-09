// Ellipsis: the loading state of 03 §8: three dots in ink.meta that fade in after 300 ms.
// The dots stand still (nothing moves at rest, 04 §1 rule 5).
pragma ComponentBehavior: Bound
import QtQuick
import qs.core

Item {
    id: root

    // Loading; the dots appear only if it lasts longer than Motion's loadingDelay.
    property bool running: false

    property bool _late: false

    implicitWidth: dots.implicitWidth
    implicitHeight: Tokens.ellipsis.dot
    opacity: running && _late ? 1 : 0
    visible: opacity > 0
    Accessible.role: Accessible.Indicator
    Accessible.name: "Loading"

    onRunningChanged: if (!running) _late = false

    Behavior on opacity {
        StandardAnimation { duration: Motion.ms("fade", !(root.running && root._late)) }
    }
    Timer {
        interval: Motion.catalogueMs("loadingDelay", false)
        running: root.running && !root._late
        onTriggered: root._late = true
    }
    Row {
        id: dots
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.ellipsis.gap

        Repeater {
            model: 3
            delegate: Rectangle {
                width: Tokens.ellipsis.dot
                height: width
                radius: width / 2
                color: Tokens.inkMeta
            }
        }
    }
}
