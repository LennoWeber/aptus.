pragma Singleton
// Wallpaper: wallpaper.json, resolution per monitor.
// Owner: S1 (resolution, drawing), S10 (gallery, thumbnails, analysis, rotation). Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): FileView on Paths.wallpaperState; pathFor() = preview › per-monitor path › default
    //   (surfaces/wallpaper.md §1); set() writes wallpaper.json atomically.

    // the parsed wallpaper.json
    property var state: ({})
    // images in wallpaper.dir, newest first: [{ path, mtime }]
    property var images: []
    // monitor name → path shown as a live preview (gallery), overrides resolution
    property var preview: ({})
    // chroma-weighted hue of the active monitor's image, -1 unknown (S10)
    property real hue: -1
    // mean OKLab lightness, -1 unknown (S10)
    property real lightness: -1

    // mean OKLCH chroma of the image, -1 unknown (S10; wallpaper.md §5)
    property real chroma: -1

    // The image a monitor shows: the gallery preview, else wallpaper.json's per-monitor path, else the default, else "" (surfaces/wallpaper.md §1).
    function pathFor(monitor: string): string { throw new Error("Wallpaper.pathFor: not implemented"); }
    // Set the wallpaper of one monitor, or of every monitor when monitor is "" (IPC `wallpaper set`).
    function set(path: string, monitor: var): void { throw new Error("Wallpaper.set: not implemented"); }
    // The next image in wallpaper.dir for the active monitor (IPC `wallpaper next`; rotation is S10).
    function next(): void { throw new Error("Wallpaper.next: not implemented"); }
}
