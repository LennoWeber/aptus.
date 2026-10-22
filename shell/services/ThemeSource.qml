pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.models

// Reads the colours of the wallpaper for the picture-based theme. The result goes to Wallpaper.colors; Tokens turns it
// into the shell colours of the chosen style (Tokens.styleColors). Settings: themeExtraction in theme/tokens.json.
Singleton {
    id: root

    // Start reading the colours of the picture at `path` (absolute). Sets Wallpaper.colors.ready when done, or
    // .failed when the picture cannot be read.
    function read(path: string): void {
        throw new Error("not implemented")
    }

    // Pure: choose up to four distinct colours from RGBA pixel data (width * height * 4 numbers), most important first.
    // `options` is themeExtraction. Returns a list of { hex, hue, saturation, lightness, share }.
    function extract(rgba: var, options: var): var {
        throw new Error("not implemented")
    }

    // The built-in colours of a style (Enums.ThemeStyle) as a list of entries, for the source Fixed and for pictures
    // that cannot be read.
    function fallbackEntries(style: int): var {
        throw new Error("not implemented")
    }
}
