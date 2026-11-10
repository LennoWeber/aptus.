pragma ComponentBehavior: Bound
// The progress activity's compact look (surfaces/notch.md §4): a 14 px ring and "42 %".
import QtQuick
import qs.core
import qs.components
import "../../core/js/format.js" as F

Item {
    id: root

    // Set by the slot (the ProgressActivity).
    property var activity: null
    property string monitorName: ""
    // The Progress item: { id, name, fraction, rate, remaining, cancellable, source }.
    readonly property var item: activity ? activity.item : null

    implicitWidth: row.implicitWidth
    implicitHeight: Tokens.surfaces.notch.compactRingSize

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.s2
        Ring {
            anchors.verticalCenter: parent.verticalCenter
            width: Tokens.surfaces.notch.compactRingSize
            height: width
            progress: root.item && root.item.fraction >= 0 ? root.item.fraction : 0
            colour: Tokens.accent
        }
        Label {
            visible: !!root.item && root.item.fraction >= 0
            anchors.verticalCenter: parent.verticalCenter
            type: "micro"
            tabular: true
            ink: "sec"
            text: root.item && root.item.fraction >= 0 ? F.percent(root.item.fraction) : ""
        }
    }
}
