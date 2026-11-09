// Tooltip: Tooltip (03 §9, M-32): raised, radius 8, body ink.main, 600 ms delay, 0 ms within 1 s of another.
// Declare it inside the control; it draws in the window's content item, above every surface.
import QtQuick
import qs.core

Item {
    id: root

    property Item target: null
    property string text: ""
    property bool active: false

    // Wanted now (the owner's hover state, a text, a visible target).
    readonly property bool _want: active && text !== "" && target !== null && target.visible
    property bool _shown: false
    // Placement in the content item, computed when it shows.
    property real _x: 0
    property real _y: 0
    readonly property real _rise: Tokens.tooltip.rise || 0

    function _show(): void {
        if (_shown || !_want) return;
        _place();
        _shown = true;
        ComponentShared.tooltipsVisible++;
    }
    function _hide(): void {
        delay.stop();
        if (!_shown) return;
        _shown = false;
        ComponentShared.tooltipsVisible = Math.max(0, ComponentShared.tooltipsVisible - 1);
        ComponentShared.tooltipHiddenAt = Date.now();
    }
    // Centred below the target, above it when there is no room; inside the window.
    function _place(): void {
        if (!target || !parent) return;
        const p = target.mapToItem(parent, 0, 0);
        const m = Tokens.s4, gap = Tokens.s2;
        _x = Math.max(m, Math.min(p.x + (target.width - width) / 2, parent.width - width - m));
        const below = p.y + target.height + gap;
        _y = below + height + m <= parent.height ? below : Math.max(m, p.y - gap - height);
    }

    parent: target ? target.Window.contentItem : null
    z: 1000
    x: _x
    y: _y + (_shown ? 0 : _rise)
    width: label.implicitWidth + 2 * Tokens.tooltip.padH
    height: label.implicitHeight + 2 * Tokens.tooltip.padV
    opacity: _shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: Motion.ms("hover", !root._shown); easing.type: Easing.BezierSpline; easing.bezierCurve: root._shown ? Motion.enter : Motion.exit }
    }
    Behavior on y {
        enabled: !Motion.reduced
        StandardAnimation { duration: Motion.ms("hover", !root._shown) }
    }

    on_WantChanged: {
        if (!_want) _hide();
        else if (ComponentShared.tooltipWarm()) _show();
        else delay.restart();
    }
    onTextChanged: if (_shown) Qt.callLater(_place)
    Component.onDestruction: _hide()

    Timer {
        id: delay
        interval: Tokens.tooltip.delay || 0
        onTriggered: root._show()
    }
    Rectangle {
        anchors.fill: parent
        radius: Tokens.tooltip.radius
        color: Tokens.raised
    }
    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        type: "body"
        ink: "main"
    }
}
