import QtQuick
import qs.models
import qs.theme
import qs.components

// Middle of the bar: shows what is relevant right now.
Item {
    id: zone

    property var items: []        // list of { id, text, severity, priority, tileId }
    property var current          // the item that wins
    property real transition: 1   // 0..1 crossfade
    property string fallbackText  // the window title, shown when no item wins
    property int priorityThreshold: 1

    implicitHeight: Tokens.barHeight

    signal tileRequested(int tileId)

    onItemsChanged: pickCurrent()
    onFallbackTextChanged: pickCurrent()
    Component.onCompleted: pickCurrent()

    // Choose the item with the highest priority.
    function pickCurrent(): void {
        const list = Array.from(items || []).filter(it => it.priority >= priorityThreshold)
        list.sort((a, b) => b.priority - a.priority)
        current = list.length > 0 ? list[0] : { text: fallbackText, severity: Enums.Severity.Neutral, priority: 0 }
    }

    // New content fades in over 140 ms, it never pops.
    NumberAnimation {
        id: fade
        target: zone
        property: "transition"
        from: 0
        to: 1
        duration: Tokens.durFast
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
    }

    onCurrentChanged: fade.restart()

    Label {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, zone.width)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
        text: zone.current ? zone.current.text : ""
        role: Enums.TextRole.Bar
        tone: zone.current ? zone.current.severity : Enums.Severity.Neutral
        // TODO(phase 7, Bild-Theming): neutral bar text uses Tokens.barInkSoft, see Bar.qml.
        color: tone === Enums.Severity.Neutral ? Tokens.inkSoft : Tokens.colorFor(tone)
        opacity: zone.transition
    }

    // The bar is 28 px, the touch target is the whole zone height of the label row plus padding.
    MouseArea {
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: label.width + 16
        height: Math.max(Tokens.barHeight, 40)
        enabled: zone.current && zone.current.tileId !== undefined
        onClicked: zone.tileRequested(zone.current.tileId)
    }
}
