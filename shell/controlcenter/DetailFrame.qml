import QtQuick
import qs.theme
import qs.components

// Container for an expanded tile: grows out of the tile's own rectangle.
Item {
    id: frame

    property int tileId  // Enums.TileId
    property string title
    property real progress  // 0..1
    property rect originRect
    property rect targetRect  // the whole board
    property Component contentComponent
    signal backRequested()

    function grow(): void {
        anim.to = 1
        anim.restart()
    }

    function shrink(): void {
        anim.to = 0
        anim.restart()
    }

    visible: progress > 0.001

    // Only position and size animate, nothing else (260 ms, the one easing).
    NumberAnimation {
        id: anim
        target: frame
        property: "progress"
        duration: Tokens.durSlow
        easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
    }

    Surface {
        x: frame.originRect.x + (frame.targetRect.x - frame.originRect.x) * frame.progress
        y: frame.originRect.y + (frame.targetRect.y - frame.originRect.y) * frame.progress
        width: frame.originRect.width + (frame.targetRect.width - frame.originRect.width) * frame.progress
        height: frame.originRect.height + (frame.targetRect.height - frame.originRect.height) * frame.progress
        cornerRadius: Tokens.radiusTile
        elevated: true

        MouseArea { anchors.fill: parent }

        // The content fades in once the frame is mostly grown.
        Item {
            anchors.fill: parent
            opacity: Math.max(0, (frame.progress - 0.4) / 0.6)

            // Visible back button for touch (Esc does the same).
            Item {
                id: back
                x: 10
                y: 10
                width: 84
                height: 40
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: Tokens.surfaceAlt
                    opacity: backArea.pressed ? 1 : backArea.containsMouse ? 0.7 : 0
                    Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                }
                StatusGlyph {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "back"
                    color: Tokens.ink
                }
                Label {
                    x: 34
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Back"
                }
                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: frame.backRequested()
                }
            }

            Label {
                anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: back.verticalCenter }
                text: frame.title
                font.weight: Font.DemiBold
            }

            Loader {
                anchors { fill: parent; leftMargin: 24; rightMargin: 24; bottomMargin: 20; topMargin: 64 }
                sourceComponent: frame.contentComponent
                onLoaded: item.expanded = true
            }
        }
    }
}
