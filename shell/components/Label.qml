import QtQuick
import qs.models
import qs.theme

// Text with the aptus type roles.
Text {
    // TODO(phase 7, polish): numbers always tabular (OpenType tnum). Needs a test on the laptop of how Qt 6.11 takes font features.

    property int role: Enums.TextRole.Body       // Enums.TextRole
    property int tone: Enums.Severity.Neutral    // Enums.Severity, colour only signals state
    property bool tabularNumbers

    font.family: role === Enums.TextRole.Mono ? Tokens.fontMono : Tokens.fontUi
    font.pixelSize: {
        switch (role) {
        case Enums.TextRole.Bar: return Tokens.sizeBar
        case Enums.TextRole.Title: return Tokens.sizeTitle
        case Enums.TextRole.Display: return Tokens.sizeDisplay
        default: return Tokens.sizeBody
        }
    }
    font.weight: role === Enums.TextRole.Title ? Font.DemiBold : role === Enums.TextRole.Display ? Font.Light : Font.Normal
    color: Tokens.colorFor(tone)
    renderType: Text.NativeRendering
}
