import QtQuick
import qs.theme

// A sample of one theme: its ground, its surface, its text colour and its accent, with the name below.
// Used by the theme picker (Super+T) and by the Theme row in Settings.
Item {
    id: swatch

    property string themeId
    property string label
    // { bg, surface, ink, accent } as colours; the theme's own, not the current theme's
    property var colors: ({})
    property bool selected          // the theme in effect
    property bool highlighted       // the keyboard or pointer rests on it
    property bool busy              // the colours are being generated (theme wallpaper)

    signal chosen()
    signal hovered()

    implicitWidth: 96
    implicitHeight: 84
}
