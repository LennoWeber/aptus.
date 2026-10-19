import QtQuick
import Quickshell

// Wallpaper picker on the blurred background.
// Phase 2/3/4 skeleton. Body comes in phase 7.
PanelWindow {
    // TODO(phase 7): grid of thumbnails on the same blur as the control center; Esc closes.

    property var wallpapers  // list of WallpaperItem
    property int selectedIndex
    property bool isOpen
    signal picked(string path)

    function show(): void {
        throw new Error("not implemented")
    }

    function hide(): void {
        throw new Error("not implemented")
    }
}
