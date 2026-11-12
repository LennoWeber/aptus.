// MenuHost: Renders the monitor's open menu (MonitorState.menu) above every surface.
// Fill the monitor with it. The menu object is { anchorX, anchorY, model, owner, onTriggered }:
// a chosen row closes the menu, then `onTriggered(row)` (a function the owner passes to
// SurfaceManager.openMenu) runs. Esc or a press outside closes it (SurfaceManager.closeMenu);
// the press still reaches what is under the pointer (05 §3), and is handled before the menu
// closes, so an owner's own button can tell "my menu was open" and not reopen it. Keyboard focus
// goes to the menu and back to where it was when the menu closes.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core

Item {
    id: root

    property MonitorState monitor

    readonly property var _menu: monitor ? monitor.menu : null
    // The menu on screen: it stays during its exit fade (M-33, 110 ms) after `monitor.menu` is null.
    property var _shown: null
    property bool _closing: false
    // The item that had the keyboard focus before the menu opened.
    property Item _focusBefore: null

    readonly property int _outMs: Motion.catalogueMs("menu", true)

    function _sync(): void {
        if (_menu) {
            exitTimer.stop();
            _closing = false;
            if (_shown !== _menu) {
                if (!_shown) _focusBefore = root.Window.activeFocusItem;
                _shown = _menu;
            }
        } else if (_shown && !_closing) {
            _closing = true;
            exitTimer.restart();
            _restoreFocus();
        }
    }
    function _restoreFocus(): void {
        const f = _focusBefore;
        _focusBefore = null;
        if (f && f.visible) f.forceActiveFocus();
    }
    function _close(): void {
        if (monitor && monitor.menu) SurfaceManager.closeMenu(monitor.name);
    }
    function _trigger(menu: var, row: var): void {
        _close();
        if (menu && typeof menu.onTriggered === "function") {
            try { menu.onTriggered(row); } catch (e) { Log.warn("surface", "menu " + (menu.owner || "") + ": " + e); }
        }
    }

    // Its window while a menu is open, marked in ComponentShared: tooltips there stay hidden.
    property var _marked: null
    function _mark(): void {
        const w = _menu ? root.Window.window : null;
        if (w === _marked) return;
        if (_marked) ComponentShared.markMenu(_marked, false);
        _marked = w;
        if (w) ComponentShared.markMenu(w, true);
    }

    on_MenuChanged: { _sync(); _mark(); }
    Window.onWindowChanged: _mark()
    Component.onCompleted: { _sync(); _mark(); }
    Component.onDestruction: if (_marked) ComponentShared.markMenu(_marked, false)

    Timer {
        id: exitTimer
        interval: root._outMs
        onTriggered: { root._shown = null; root._closing = false; }
    }
    // Outside presses close the menu after they were delivered (accepted = false lets them through).
    MouseArea {
        anchors.fill: parent
        enabled: root._shown !== null && !root._closing
        acceptedButtons: Qt.AllButtons
        onPressed: event => {
            event.accepted = false;
            Qt.callLater(root._close);
        }
    }
    Repeater {
        model: root._shown ? [root._shown] : []
        delegate: Item {
            id: holder
            required property var modelData
            width: root.width
            height: root.height
            opacity: root._closing ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: root._outMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.exit }
            }
            Menu {
                id: menu
                model: holder.modelData.model || []
                anchorX: Number(holder.modelData.anchorX) || 0
                anchorY: Number(holder.modelData.anchorY) || 0
                enabled: !root._closing
                onTriggered: row => root._trigger(holder.modelData, row)
                onDismissed: root._close()
                Component.onCompleted: menu.forceActiveFocus()
            }
        }
    }
}
