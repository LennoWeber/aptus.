pragma ComponentBehavior: Bound
// The progress card (surfaces/notch.md §5, 420 × 80): name, percent, rate and remaining if known;
// Cancel only when the source offers it.
import QtQuick
import qs.core
import qs.services
import qs.components
import "../../core/js/format.js" as F

Item {
    id: root

    // Set by the card host (ActivityCard).
    property string monitorName: ""
    property var activity: null
    property bool pinned: false
    // The Progress item shown.
    readonly property var item: activity ? activity.item : null

    Row {
        anchors.fill: parent
        spacing: Tokens.s5
        Ring {
            anchors.verticalCenter: parent.verticalCenter
            width: Tokens.surfaces.card.timerRingSize
            height: width
            progress: root.item && root.item.fraction >= 0 ? root.item.fraction : 0
            colour: Tokens.accent
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - (cancel.visible ? cancel.width + parent.spacing : 0)
            spacing: Tokens.s1
            Label {
                width: parent.width
                type: "bodyStrong"
                elide: Text.ElideRight
                text: root.item ? root.item.name : ""
            }
            Label {
                width: parent.width
                type: "body"
                ink: "sec"
                tabular: true
                elide: Text.ElideRight
                text: root.item ? [root.item.fraction >= 0 ? F.percent(root.item.fraction) : "",
                                   root.item.rate, root.item.remaining].filter(s => s !== "").join(" · ") : ""
            }
        }
        Button {
            id: cancel
            visible: !!root.item && root.item.cancellable
            anchors.verticalCenter: parent.verticalCenter
            text: "Cancel"
            variant: "quiet"
            onClicked: Progress.cancel(root.item.id)
        }
    }
}
