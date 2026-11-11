pragma Singleton
import QtQuick
// Test double of qs.services Hypr for the bar's surfaces: the monitors and the actions they call
// (recorded in `calls` as [name, args…], nothing dispatched).
QtObject {
    property var monitors: []
    property var calls: []
    function _call(name: string, args: var): void { calls = calls.concat([[name].concat(args)]); }
    function focusWorkspace(workspace: string): void { _call("focusWorkspace", [workspace]); }
    function moveToWorkspace(address: string, workspace: string): void { _call("moveToWorkspace", [address, workspace]); }
    function closeWorkspaceWindows(id: int): void { _call("closeWorkspaceWindows", [id]); }
    function moveWorkspaceToMonitor(id: int, monitor: string): void { _call("moveWorkspaceToMonitor", [id, monitor]); }
    function toggleScratch(): void { _call("toggleScratch", []); }
}
