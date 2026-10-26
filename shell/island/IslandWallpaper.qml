import QtQuick
import qs.models
import qs.theme
import qs.services
import qs.components

// Wallpaper view: the pictures come out of the island one after the other as a row of cards; the one in the middle
// is chosen with the arrow keys, the wheel or a tap, and set at once.
Item {
    id: wall

    property int selectedIndex
    property real reveal       // 0..1, how far the cards have come out of the island
    property bool active       // the view is the one shown
    property color ink
    property color inkSoft
    property color line

    signal closeRequested()

    // How many cards are shown around the middle one.
    readonly property int visibleSide: 3
    readonly property int cardWidth: 200
    readonly property int cardHeight: 112

    // Move the middle card by delta pictures.
    function step(delta: int): void {
        throw new Error("not implemented")
    }

    // Set the middle picture as wallpaper.
    function activateSelected(): void {
        throw new Error("not implemented")
    }

    // Scan the folder and start the reveal when the view is shown.
    function show(): void {
        throw new Error("not implemented")
    }

    // Take the cards back when the view is left.
    function hide(): void {
        throw new Error("not implemented")
    }
}
