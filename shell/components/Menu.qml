// Menu: Floating menu (03 §9): raised, radius 12, 6 padding, rows 30, shadow; separators 1 px line inset 8 (M-33).
// Placed in its parent's coordinates (MenuHost: monitor-local). It grows from the anchor (scale
// 0.96 → 1 + fade, `enter` 160) down and to the right, flipping left/up when there is no room.
// Submenus open on click, Enter or → (05 §4: nothing opens under a passing pointer) and close on
// ← or Esc; `confirm` rows ask once in the row (bar.md §3) and run on a second trigger within
// Tokens.surfaces.spotlight.destructiveConfirmMs; anything else cancels.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.core

Item {
    id: root

    // [{ id, label, glyph, keys: "Ctrl+Enter", risk: bool, confirm: "Press again to …" (inline confirm,
    //    bar.md §3), enabled: bool, separator: bool, checked: bool, submenu: [...] }]
    property var model: []
    // The point the menu grows from (monitor-local).
    property real anchorX: 0
    property real anchorY: 0
    property int currentIndex: -1
    signal triggered(var row)
    signal dismissed()

    // Keyboard: ↑ ↓ move (skipping separators and disabled rows), Enter triggers.
    function moveCurrent(delta: int): void {
        const n = model.length;
        if (n === 0 || delta === 0) return;
        const dir = delta > 0 ? 1 : -1;
        let i = currentIndex;
        for (let k = 0; k < Math.abs(delta); k++) {
            let j = i;
            for (let s = 0; s < n; s++) {
                j = j < 0 ? (dir > 0 ? 0 : n - 1) : (j + dir + n) % n;
                if (_usable(j)) break;
            }
            if (!_usable(j)) return;
            i = j;
        }
        _setCurrent(i);
    }
    function triggerCurrent(): void { _activate(currentIndex, true); }

    // Edges to flip to when the menu does not fit right of / below the anchor (a submenu flips
    // to the other side of its parent menu).
    property real _altX: anchorX
    property real _altY: anchorY
    // Nesting depth (0: the root menu; ← closes a submenu).
    property int _level: 0
    property int _confirmIndex: -1
    property int _subIndex: -1
    // Entrance progress 0 → 1 (M-33).
    property real _appear

    readonly property real _pad: Tokens.menu.padding
    readonly property real _margin: Tokens.s4
    readonly property real _rowRadius: Tokens.menu.radius - Tokens.menu.padding
    readonly property bool _hasLead: {
        for (let i = 0; i < model.length; i++) {
            const r = model[i];
            if (r && !r.separator && (r.glyph || r.risk || r.confirm)) return true;
        }
        return false;
    }
    readonly property real _rowsWidth: {
        let w = 0;
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (it) w = Math.max(w, it.implicitWidth);
        }
        return w;
    }
    readonly property real _space: parent ? parent.width : 0
    readonly property real _spaceV: parent ? parent.height : 0

    function _usable(i: int): bool {
        const r = i >= 0 && i < model.length ? model[i] : null;
        return !!r && !r.separator && r.enabled !== false;
    }
    function _hasSub(i: int): bool {
        const r = i >= 0 && i < model.length ? model[i] : null;
        return !!r && !!r.submenu && r.submenu.length > 0;
    }
    function _setCurrent(i: int): void {
        if (i === currentIndex) return;
        currentIndex = i;
        if (_confirmIndex >= 0 && _confirmIndex !== i) _cancelConfirm();
    }
    function _cancelConfirm(): void {
        _confirmIndex = -1;
        confirmTimer.stop();
    }
    function _activate(i: int, viaKeyboard: bool): void {
        if (!_usable(i)) return;
        _setCurrent(i);
        const row = model[i];
        if (_hasSub(i)) { _openSub(i, viaKeyboard); return; }
        if (row.confirm && _confirmIndex !== i) {
            _confirmIndex = i;
            confirmTimer.restart();
            return;
        }
        _cancelConfirm();
        root.triggered(row);
    }
    function _openSub(i: int, viaKeyboard: bool): void {
        if (_subIndex === i && sub.item) { (sub.item as Item).forceActiveFocus(); return; }
        _closeSub(false);
        const it = rep.itemAt(i);
        if (!it) return;
        const top = y + rows.y + it.y - _pad;
        _subIndex = i;
        sub.setSource(Qt.resolvedUrl("Menu.qml"), {
            model: model[i].submenu,
            anchorX: x + width - _pad, anchorY: top,
            _altX: x + _pad, _altY: top + it.height + 2 * _pad,
            _level: _level + 1,
            currentIndex: -1
        });
        const m = sub.item as Menu;
        if (!m) return;
        m.forceActiveFocus();
        if (viaKeyboard) m.moveCurrent(1);
    }
    function _closeSub(refocus: bool): void {
        if (_subIndex < 0) return;
        _subIndex = -1;
        sub.source = "";
        if (refocus) root.forceActiveFocus();
    }

    x: anchorX + width + _margin <= _space ? anchorX : Math.max(_margin, _altX - width)
    y: anchorY + height + _margin <= _spaceV ? anchorY : Math.max(_margin, _altY - height)
    width: Math.min(_rowsWidth + 2 * _pad, Math.max(0, _space - 2 * _margin))
    height: rows.implicitHeight + 2 * _pad
    focus: true
    opacity: _appear
    transform: Scale {
        readonly property real from: Motion.reduced ? 1 : (Motion.catalogue.menu ? Motion.catalogue.menu.scaleFrom : 1)
        origin.x: root.anchorX - root.x
        origin.y: root.anchorY - root.y
        xScale: from + (1 - from) * root._appear
        yScale: xScale
    }
    Accessible.role: Accessible.PopupMenu

    NumberAnimation on _appear {
        from: 0
        to: 1
        duration: Motion.catalogueMs("menu", false)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.enter
    }

    Keys.onPressed: event => {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const k = event.key;
        if (k === Qt.Key_Up || (ctrl && k === Qt.Key_P)) root.moveCurrent(-1);
        else if (k === Qt.Key_Down || (ctrl && k === Qt.Key_N)) root.moveCurrent(1);
        else if (k === Qt.Key_Home) { root._setCurrent(-1); root.moveCurrent(1); }
        else if (k === Qt.Key_End) { root._setCurrent(-1); root.moveCurrent(-1); }
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.triggerCurrent();
        else if (k === Qt.Key_Right && root._hasSub(root.currentIndex)) root._openSub(root.currentIndex, true);
        else if (k === Qt.Key_Escape || (k === Qt.Key_Left && root._level > 0)) root.dismissed();
        else {
            if (root._confirmIndex >= 0) root._cancelConfirm();
            return;
        }
        event.accepted = true;
    }

    Timer {
        id: confirmTimer
        interval: Tokens.surfaces.spotlight ? Tokens.surfaces.spotlight.destructiveConfirmMs : 0
        onTriggered: root._confirmIndex = -1
    }

    // The shadow (03 §3) sits under the plain background, so the menu still draws where shader
    // effects are unavailable (software scene graph).
    MultiEffect {
        anchors.fill: background
        source: background
        shadowEnabled: true
        shadowColor: Tokens.shadow
        shadowVerticalOffset: Tokens.shadowOffsetY
        blurMax: Tokens.shadowBlur
        shadowBlur: 1
    }
    Rectangle {
        id: background
        anchors.fill: parent
        radius: Tokens.menu.radius
        color: Tokens.raised
    }
    // Presses on the padding and separators stay in the menu (MenuHost's outside catcher is below).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    component MenuRow: Item {
        id: row
        required property var modelData
        required property int index
        readonly property bool separator: !!modelData.separator
        readonly property bool usable: root._usable(index)
        readonly property bool confirming: root._confirmIndex === index
        readonly property bool risky: !!modelData.risk || confirming
        readonly property bool sub: root._hasSub(index)
        readonly property string leadGlyph: confirming ? "warning" : modelData.glyph ? String(modelData.glyph) : modelData.risk ? "warning" : ""
        readonly property string ink: !usable ? "faint" : risky ? "crit" : "main"

        width: rows.width
        height: separator ? Tokens.s4 + Tokens.menu.separatorWidth : Tokens.menu.rowHeight
        implicitWidth: separator ? 0 : Tokens.padRowH * 2 + (root._hasLead ? Tokens.glyphRow + Tokens.gapRowIcon : 0)
                                       + label.implicitWidth + (trail.width > 0 ? Tokens.s8 + trail.width : 0)
        Accessible.role: separator ? Accessible.Separator : Accessible.MenuItem
        Accessible.name: separator ? "" : String(label.text)
        Accessible.checkable: modelData.checked !== undefined
        Accessible.checked: modelData.checked === true

        Rectangle {
            visible: row.separator
            x: Tokens.menu.separatorInset
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 2 * Tokens.menu.separatorInset
            height: Tokens.menu.separatorWidth
            color: Tokens.line
        }
        Wash {
            visible: !row.separator
            anchors.fill: parent
            radius: root._rowRadius
            current: row.usable && (root.currentIndex === row.index || root._subIndex === row.index)
            hovered: row.usable && mouse.containsMouse
            pressed: row.usable && mouse.pressed
        }
        Glyph {
            id: lead
            x: Tokens.padRowH
            anchors.verticalCenter: parent.verticalCenter
            visible: !row.separator && row.leadGlyph !== ""
            name: row.leadGlyph
            size: Tokens.glyphRow
            colour: ComponentShared.ink(row.usable && !row.risky ? "sec" : row.ink)
        }
        Label {
            id: label
            visible: !row.separator
            x: Tokens.padRowH + (root._hasLead ? Tokens.glyphRow + Tokens.gapRowIcon : 0)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, (trail.width > 0 ? trail.x - Tokens.s8 : row.width - Tokens.padRowH) - x)
            text: row.separator ? "" : String(row.confirming ? row.modelData.confirm : (row.modelData.label || ""))
            ink: row.ink
        }
        Item {
            id: trail
            visible: !row.separator
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padRowH
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? trailRow.implicitWidth : 0
            height: trailRow.implicitHeight

            Item {
                id: trailRow
                implicitWidth: (keys.visible ? keys.implicitWidth : 0) + (mark.visible ? (keys.visible ? Tokens.s4 : 0) + mark.width : 0)
                implicitHeight: Tokens.glyphRow

                Label {
                    id: keys
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!row.modelData.keys
                    text: row.modelData.keys ? String(row.modelData.keys) : ""
                    type: "micro"
                    ink: row.usable ? "meta" : "faint"
                    elide: Text.ElideNone
                }
                Glyph {
                    id: mark
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.sub || row.modelData.checked === true
                    name: row.sub ? "chevron_right" : "check"
                    size: Tokens.glyphRow
                    on: !row.sub
                    colour: !row.usable ? Tokens.inkFaint : row.sub ? Tokens.inkMeta : Tokens.accent
                }
            }
        }
        MouseArea {
            id: mouse
            visible: !row.separator
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: if (containsMouse && row.usable && root._subIndex < 0) root._setCurrent(row.index)
            onClicked: {
                if (root._subIndex >= 0 && root._subIndex !== row.index) root._closeSub(true);
                root._activate(row.index, false);
            }
        }
    }

    Column {
        id: rows
        x: root._pad
        y: root._pad
        width: root.width - 2 * root._pad

        Repeater {
            id: rep
            model: root.model
            delegate: MenuRow {}
        }
    }

    // The open submenu: a sibling in the parent's coordinates, above this menu.
    Loader {
        id: sub
        parent: root.parent
        anchors.fill: parent
        z: root.z + 1

        Connections {
            target: sub.item
            ignoreUnknownSignals: true
            function onTriggered(row: var): void { root.triggered(row); }
            function onDismissed(): void { root._closeSub(true); }
        }
    }
}
