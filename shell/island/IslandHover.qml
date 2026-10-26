import QtQuick
import qs.models
import qs.theme
import qs.components
import qs.services

// The hover panel: the quick settings that the bar's dropdowns had, in one card (volume, brightness, switches,
// music, battery), shown while the pointer rests on the island.
Item {
    id: hoverPanel

    property var appSettings
    property var audioState
    property var displayState
    property var networkState
    property var bluetoothState
    property var batteryState
    property var nightLightState
    property var caffeineState
    property var focusState
    property var mediaState
    property color ink
    property color inkSoft
    property color line
    property color fill       // the island's fill, for the glyph on an ink-filled switch

    signal tileRequested(int tileId)
    signal controlCenterRequested()
}
