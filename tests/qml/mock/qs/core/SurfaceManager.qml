pragma Singleton
import QtQuick
// Test double of qs.core SurfaceManager for tst_components (qmltestrunner cannot load Quickshell).
QtObject {
    property var monitors: ({})
    property int closeCalls: 0
    function openMenu(monitor: string, menu: var): void { monitors[monitor].menu = menu; }
    function closeMenu(monitor: string): void { closeCalls++; if (monitors[monitor]) monitors[monitor].menu = null; }
}
