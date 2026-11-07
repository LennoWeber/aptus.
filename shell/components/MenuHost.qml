// MenuHost: Renders the monitor's open menu (MonitorState.menu) above every surface.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): shows Menu for monitor.menu; dismissed → SurfaceManager.closeMenu.

    property MonitorState monitor
}
