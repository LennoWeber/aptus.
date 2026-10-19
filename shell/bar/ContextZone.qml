import QtQuick
import qs.models
import qs.theme
import qs.components

// Middle of the bar: shows what is relevant right now.
Item {
    id: zone
    // TODO(phase 7, context items): feed ContextItems from media, timer, downloads and notifications (later sections); the slide-in part of the transition comes with them.

    property var items: []        // list of ContextItem
    property var current          // ContextItem that wins
    property real transition: 1   // 0..1 crossfade
    property string fallbackText  // the window title, shown when no item wins
    property int priorityThreshold: 1

    implicitHeight: Tokens.barHeight

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
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, zone.width)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
        text: zone.current ? zone.current.text : ""
        role: Enums.TextRole.Bar
        tone: zone.current ? zone.current.severity : Enums.Severity.Neutral
        color: tone === Enums.Severity.Neutral ? Tokens.inkSoft : Tokens.colorFor(tone)
        opacity: zone.transition
    }
}
