// Slider: Slider (03 §9): 4 px track, accent fill, 16 px thumb; leading glyph by level; value label (M-19).
// Controlled: it emits moved(value) and the owner writes `value`; while dragging it shows the
// dragged value itself.
import QtQuick
import qs.core

Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.05
    // Leading glyph; with `levelGlyphs` the glyph follows the value (volume: 0/33/66/100).
    property string glyph: ""
    property var levelGlyphs: []
    property string valueText: ""
    property string accessibleName: ""
    property bool keyboardFocus: false
    readonly property bool dragging: _dragging
    signal moved(real value)
    // A click on the leading glyph (deck.md §4: click = mute).
    signal glyphClicked()

    property bool _dragging: false
    property real _dragValue: 0
    property real _pressX: 0
    readonly property real _shown: _dragging ? _dragValue : value
    readonly property real _fraction: to > from ? Math.max(0, Math.min(1, (_shown - from) / (to - from))) : 0
    // Index into levelGlyphs: 0 at the bottom of the range, then one per Tokens.slider.volumeSteps
    // interval (0, (0,33], (33,66], (66,100]); other lengths spread evenly.
    readonly property int _level: {
        const n = levelGlyphs.length, steps = Tokens.slider.volumeSteps || [];
        if (n === 0) return -1;
        const pct = _fraction * 100;
        if (n !== steps.length) return Math.round(_fraction * (n - 1));
        let idx = 0;
        for (let i = 1; i < n; i++) if (pct > steps[i - 1]) idx = i;
        return idx;
    }
    readonly property string _glyph: _level >= 0 ? String(levelGlyphs[_level]) : glyph

    function _clamp(v: real): real { return Math.max(Math.min(from, to), Math.min(Math.max(from, to), v)); }
    function _snap(v: real): real { return step > 0 ? _clamp(from + Math.round((v - from) / step) * step) : _clamp(v); }
    function _valueAt(px: real): real {
        const span = track.width - thumb.width;
        return span > 0 ? _clamp(from + (px - thumb.width / 2) / span * (to - from)) : from;
    }

    implicitHeight: Math.max(Tokens.hitMin, Tokens.slider.thumb)
    implicitWidth: lead.width + trail.width + Tokens.s10 * 4
    Accessible.role: Accessible.Slider
    Accessible.name: accessibleName
    Accessible.onIncreaseAction: root.moved(root._snap(root.value + root.step))
    Accessible.onDecreaseAction: root.moved(root._snap(root.value - root.step))

    // deck.md §4: ← → by the step (Shift: 1 % of the range), Home/End min/max; ↑ ↓ stay with the surface.
    Keys.onPressed: event => {
        const fine = (event.modifiers & Qt.ShiftModifier) ? (to - from) / 100 : step;
        let v = NaN;
        if (event.key === Qt.Key_Left) v = value - fine;
        else if (event.key === Qt.Key_Right) v = value + fine;
        else if (event.key === Qt.Key_Home) v = from;
        else if (event.key === Qt.Key_End) v = to;
        if (isNaN(v)) return;
        root.moved((event.modifiers & Qt.ShiftModifier) ? root._clamp(v) : root._snap(v));
        event.accepted = true;
    }

    Item {
        id: lead
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root._glyph !== "" ? Tokens.hitMin : 0
        height: Tokens.hitMin
        visible: root._glyph !== ""

        Wash {
            anchors.fill: parent
            hovered: leadMouse.containsMouse
            pressed: leadMouse.pressed
        }
        Glyph {
            anchors.centerIn: parent
            name: root._glyph
            size: Tokens.glyphRow
            colour: root.enabled ? Tokens.inkSec : Tokens.inkFaint
        }
        MouseArea {
            id: leadMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.glyphClicked()
        }
    }
    Label {
        id: trail
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.valueText !== ""
        // wide enough for three figures, so the track does not move as the value changes
        width: visible ? Math.max(implicitWidth, widest.advanceWidth) : 0
        horizontalAlignment: Text.AlignRight
        text: root.valueText
        type: "body"
        ink: "meta"
        tabular: true

        TextMetrics {
            id: widest
            font: trail.font
            text: "000"
        }
    }
    Item {
        id: track
        anchors.left: lead.right
        anchors.leftMargin: lead.visible ? Tokens.s4 : 0
        anchors.right: trail.left
        anchors.rightMargin: trail.visible ? Tokens.s5 : 0
        anchors.verticalCenter: parent.verticalCenter
        height: Math.max(Tokens.hitMin, Tokens.slider.thumb)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Tokens.slider.track
            radius: height / 2
            color: Tokens.line
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: thumb.x + thumb.width / 2
            height: Tokens.slider.track
            radius: height / 2
            color: root.enabled ? Tokens.accent : Tokens.inkFaint
        }
        Rectangle {
            id: thumb
            anchors.verticalCenter: parent.verticalCenter
            width: Tokens.slider.thumb
            height: width
            radius: width / 2
            x: root._fraction * (track.width - width)
            color: root.enabled ? Tokens.inkMain : Tokens.inkFaint

            // M-19: 1:1 while dragging; click, wheel and keys move it on the snappy spring
            Behavior on x {
                enabled: !root._dragging && !Motion.reduced
                SpringAnimation { spring: Motion.snappySpring; damping: Motion.snappyDamping; mass: Motion.snappyMass; epsilon: Motion.snappyEpsilon }
            }
            FocusRing {
                target: thumb
                targetRadius: thumb.radius
                shown: root.keyboardFocus
            }
        }
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            onPressed: event => {
                root._pressX = event.x;
                root._dragValue = root._valueAt(event.x);
                // on the thumb the drag starts at once; on the track the thumb jumps (spring) first
                if (Math.abs(event.x - (thumb.x + thumb.width / 2)) <= thumb.width / 2) root._dragging = true;
                root.moved(root._dragValue);
            }
            onPositionChanged: event => {
                if (!root._dragging && Math.abs(event.x - root._pressX) >= Tokens.dragThreshold) root._dragging = true;
                if (!root._dragging) return;
                root._dragValue = root._valueAt(event.x);
                root.moved(root._dragValue);
            }
            onReleased: root._dragging = false
            onCanceled: root._dragging = false
            onWheel: event => {
                const notches = event.angleDelta.y !== 0 ? event.angleDelta.y / 120 : -event.angleDelta.x / 120;
                if (notches !== 0) root.moved(root._snap(root.value + notches * root.step));
            }
        }
    }
}
