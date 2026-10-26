pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.models
import qs.theme
import qs.components

// The theme choice behind Super+T: a small card at the top of the focused screen with one ThemeSwatch per theme. Arrow keys
// or Super+T again move on and the shell shows the theme at once; Enter or a click keeps it (the apps follow then), Esc puts
// the theme back that was in effect when the card opened.
PanelWindow {
    id: picker

    property var themeState                   // ColorModeState
    property bool isOpen
    property int selectedIndex
    property string startThemeId              // the theme in effect when the card opened; Esc returns to it
    property var entries: Tokens.themeList    // { id, name, base, bg, surface, ink, accent }
    property real reveal: isOpen ? 1 : 0

    visible: false
    color: "transparent"
}
