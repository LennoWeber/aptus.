pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.models
import qs.theme

// Reads the colours of the wallpaper for the picture-based theme. The result goes to Wallpaper.colors; Tokens turns it
// into the shell colours of the chosen style (Tokens.styleColors). Settings: themeExtraction in theme/tokens.json.
Singleton {
    id: root

    // Reads the picture scaled down, as text: `magick <path> -resize <sampleWidth>x -depth 8 txt:-` (ImageMagick). read() fills it in.
    Process {
        id: reader
        stdout: StdioCollector { id: readerOutput }
    }

    // Start reading the colours of the picture at `path` (absolute). Sets Wallpaper.colors.ready when done, or
    // .failed when the picture cannot be read.
    function read(path: string): void {
        throw new Error("not implemented")
    }

    // Pure: choose up to four distinct colours from RGBA pixel data (width * height * 4 numbers), most important first.
    // `options` is themeExtraction. Returns a list of { hex, hue, saturation, lightness, share }; a flat picture gives fewer
    // than four, Tokens.styleColors fills up from the style's fallbackColors.
    function extract(rgba: var, options: var): var {
        throw new Error("not implemented")
    }
}
