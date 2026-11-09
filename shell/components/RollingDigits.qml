// RollingDigits: Rolling digits (03 §9, M-34): tabular figures where only changed digits roll.
// Characters are matched from the right ("9:59" → "10:00" rolls the minutes and brings the new
// leading digit in); a changed digit rises out 6 px and fades while the new one rises from below
// (`fade`, `standard`). No rolls with reduced motion.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core

Item {
    id: root

    // The text to show ("14:32", "64 %"); characters that are not digits never roll.
    property string text: ""
    // Type role of 03 §4 ("clock", "micro", "number", …).
    property string role: "body"
    property color colour

    readonly property color _colour: colour.valid ? colour : Tokens.inkMain
    readonly property real _rise: Tokens.rollingDigits.rise || 0
    // Rolls start after the first text is in place.
    property bool _ready: false

    // One model row per character, right-aligned: growth inserts and shrinking removes at the front.
    function _sync(): void {
        const t = text;
        while (cells.count > t.length) cells.remove(0);
        while (cells.count < t.length) cells.insert(0, { ch: _ready ? "" : t.charAt(t.length - cells.count - 1) });
        for (let i = 0; i < t.length; i++) if (cells.get(i).ch !== t.charAt(i)) cells.setProperty(i, "ch", t.charAt(i));
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Tokens.font(role).lineHeight
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    onTextChanged: _sync()
    Component.onCompleted: { _sync(); _ready = true; }

    ListModel { id: cells }

    component Cell: Item {
        id: cell
        required property string ch
        // The character before the last change and the progress of its roll (1 = settled).
        property string _old: ""
        property string _last: ""
        property real _t: 1

        width: Math.max(now.implicitWidth, _t < 1 ? before.implicitWidth : 0)
        height: root.implicitHeight

        onChChanged: {
            const rolls = root._ready && !Motion.reduced && ch >= "0" && ch <= "9" && ch !== _last;
            _old = _last;
            _last = ch;
            if (rolls) roll.restart();
            else { roll.stop(); _t = 1; }
        }
        Component.onCompleted: _last = ch

        StandardAnimation {
            id: roll
            target: cell
            property: "_t"
            from: 0
            to: 1
            duration: Motion.ms("fade", false)
        }
        Label {
            id: before
            visible: cell._t < 1
            y: -root._rise * cell._t
            opacity: 1 - cell._t
            text: cell._old
            type: root.role
            tabular: true
            color: root._colour
            elide: Text.ElideNone
        }
        Label {
            id: now
            y: root._rise * (1 - cell._t)
            opacity: cell._t
            text: cell.ch
            type: root.role
            tabular: true
            color: root._colour
            elide: Text.ElideNone
        }
    }

    Row {
        id: row

        Repeater {
            model: cells
            delegate: Cell {}
        }
    }
}
