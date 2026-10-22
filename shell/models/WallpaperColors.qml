import QtQuick

// The colours read from a wallpaper (see themeExtraction in theme/tokens.json): up to four distinct colours,
// most important first. Filled by ThemeSource; Tokens turns them into the shell colours of the chosen style.
QtObject {
    id: colors

    property string path             // the picture the colours were read from, empty = none yet
    property var entries: []         // list of { hex, hue (0..360), saturation (0..100), lightness (0..100), share (0..1) }
    property bool ready              // true once entries belong to `path`
    property bool failed             // the picture could not be read; Tokens then uses the style's fallbackColors
}
