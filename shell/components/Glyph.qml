// Glyph: A Material Symbols Rounded glyph (03 §5). FILL and wght follow `on`/`active` and animate (P-17);
// a change of `name` crossfades the old glyph out and scales the new one 0.8 → 1 (04 §3 rule 6), so
// Glyph is an Item holding two Texts.
import QtQuick
import qs.core

Item {
    id: root

    // The symbol name (ligature), e.g. "wifi".
    property string name: ""
    property real size: Tokens.glyphRow
    // FILL 1 when on.
    property bool on: false
    // wght 500 when active.
    property bool active: false
    property color colour

    // The face's font (variable axes included), for callers and tests.
    readonly property font font: face.font

    implicitWidth: size
    implicitHeight: size
    Accessible.ignored: true

    // Private state.
    // The animated axis values (04 §3 rule 6: FILL 0↔1 and wght 400↔500 over `small`).
    property real _fill: on ? 1 : 0
    property real _wght: active ? Tokens.glyphWeightActive : Tokens.glyphWeightRest
    // The glyph shown now, the one being swapped out, and the swap progress 0 → 1.
    property string _current: ""
    property string _previous: ""
    property real _swap: 1
    // Axes shared by both faces; opsz follows the size inside the font's range (20..48), GRAD the mode.
    readonly property var _axes: ({ "FILL": _fill, "wght": _wght, "GRAD": Tokens.glyphGrad, "opsz": Math.max(20, Math.min(48, size)) })
    readonly property color _ink: colour.valid ? colour : Tokens.inkMain

    Component.onCompleted: _current = name
    onNameChanged: {
        if (_current === name) return;
        _previous = _current;
        _current = name;
        if (_previous === "" || name === "") { swap.stop(); _swap = 1; return; }
        swap.restart();
    }

    NumberAnimation {
        id: swap
        target: root; property: "_swap"; from: 0; to: 1
        duration: Motion.ms("small", false)
        easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standard
    }

    Text {
        // the glyph leaving
        anchors.fill: parent
        visible: root._swap < 1
        opacity: 1 - root._swap
        text: root._previous
        color: root._ink
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
        font.family: ComponentShared.glyphFamily
        font.pixelSize: root.size
        font.variableAxes: root._axes
    }
    Text {
        id: face
        anchors.fill: parent
        opacity: root._swap
        // reduced motion: a plain crossfade (04 §7)
        scale: Motion.reduced ? 1 : Motion.iconSwapScale + (1 - Motion.iconSwapScale) * root._swap
        text: root._current
        color: root._ink
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
        font.family: ComponentShared.glyphFamily
        font.pixelSize: root.size
        font.variableAxes: root._axes
    }

    Behavior on _fill {
        enabled: !Motion.reduced
        NumberAnimation { duration: Motion.ms("small", !root.on); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standard }
    }
    Behavior on _wght {
        enabled: !Motion.reduced
        NumberAnimation { duration: Motion.ms("small", !root.active); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standard }
    }
}
