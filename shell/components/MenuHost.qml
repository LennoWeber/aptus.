// MenuHost: Renders the monitor's open menu (MonitorState.menu) above every surface.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): shows Menu for monitor.menu; dismissed → SurfaceManager.closeMenu.

    property MonitorState monitor

    // Private state.
    readonly property var _menu: ({})
    // The menu on screen: it stays during its exit fade (M-33, 110 ms) after `monitor.menu` is null.
    property var _shown: null
    property bool _closing: false
    // The item that had the keyboard focus before the menu opened.
    property Item _focusBefore: null
    readonly property int _outMs: 0

    // Private helpers.
    function _sync(): void { throw new Error("MenuHost._sync: not implemented"); }
    function _restoreFocus(): void { throw new Error("MenuHost._restoreFocus: not implemented"); }
    function _close(): void { throw new Error("MenuHost._close: not implemented"); }
    function _trigger(menu: var, row: var): void { throw new Error("MenuHost._trigger: not implemented"); }
}
