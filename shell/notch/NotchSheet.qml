import QtQuick
import qs.models
import qs.theme
import qs.components
import qs.bar

// The opened notch: the player when something plays, the line that matters now, the workspaces and the status icons
// that open the dropdowns. The top row (wordmark, time, controls) is the pill itself.
Item {
    id: sheet

    property var mediaState
    property var audioState
    property var networkState
    property var bluetoothState
    property var batteryState
    property var nightLightState
    property var caffeineState
    property var focusState
    property var workspaces
    property string contextText         // the winning line of ContextState, else the window title
    property var appSettings
    property bool shown
    property bool mediaWings: true
    property string look: "light"

    // The height the sheet wants under the pill, with and without the player.
    property real bodyHeight

    signal dropdownRequested(int dropdownId, var anchorItem)
    signal tileRequested(int tileId)
    signal workspaceRequested(int workspaceId)
}
