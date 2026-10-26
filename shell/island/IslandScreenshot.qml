import QtQuick
import qs.models
import qs.theme
import qs.services
import qs.components

// Screenshot view: region, screen, window, and screen recording (start and stop).
FocusScope {
    id: shot

    property var captureState  // CaptureState
    property int selectedIndex
    property var actions       // { id, label, glyph }
    property color ink
    property color inkSoft
    property color line

    signal closeRequested()

    readonly property var defaultActions: [
        { id: "region", label: "Region", glyph: "capture" },
        { id: "screen", label: "Screen", glyph: "display" },
        { id: "window", label: "Window", glyph: "window" },
        { id: "record", label: "Record", glyph: "record" }
    ]

    // Take the screenshot or start / stop the recording; the island closes first so it is not in the picture.
    function run(actionId: string): void {
        throw new Error("not implemented")
    }

    function moveSelection(delta: int): void {
        throw new Error("not implemented")
    }

    function activateSelected(): void {
        throw new Error("not implemented")
    }

    function reset(): void {
        throw new Error("not implemented")
    }
}
