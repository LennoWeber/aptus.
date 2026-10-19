pragma Singleton
import QtQuick

// Signatures only. Bodies come in phase 7.
QtObject {
    // Wallpapers with thumbnails.
    function scan(directory: string): var {
        if (!directory) throw new Error("invariant: Wallpaper.scan: empty directory")
        throw new Error("not implemented")
    }

    function setWallpaper(path: string): void {
        if (!path || path[0] !== "/") throw new Error("invariant: Wallpaper.setWallpaper: path must be absolute")
        // TODO(phase 7): hyprpaper or similar; the greeter wallpaper follows greeter.json.
        throw new Error("not implemented")
    }

    function thumbnailFor(path: string): string {
        if (!path || path[0] !== "/") throw new Error("invariant: Wallpaper.thumbnailFor: path must be absolute")
        throw new Error("not implemented")
    }
}
