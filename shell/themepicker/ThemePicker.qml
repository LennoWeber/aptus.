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

    // TODO(phase 7, themes): layer-shell window like WallpaperPicker (Overlay, exclusive keyboard while open, screen of the focused monitor, anchors top centre, exclusionMode Ignore); a Surface with a row of ThemeSwatch over `entries`; keys: Left/Right/Tab move, Enter keeps, Escape cancels, Super+T is the IPC call; a click outside keeps; a short caption with the theme name under the row; the card fades in with `reveal`.

    // Open on the focused screen with the theme in effect selected, remember it as startThemeId.
    function show(): void {
        if (!themeState) throw new Error("invariant: ThemePicker.show: themeState not set")
        if (entries.length === 0) throw new Error("invariant: ThemePicker.show: Tokens.themeList is empty (tokens not loaded)")
        throw new Error("not implemented")
    }

    // Close. `keep` true keeps the selected theme (commit), false puts the starting theme back.
    function hide(keep: bool): void {
        if (!themeState) throw new Error("invariant: ThemePicker.hide: themeState not set")
        throw new Error("not implemented")
    }

    // Super+T: open when closed, else move on to the next theme.
    function toggle(): void {
        throw new Error("not implemented")
    }

    // Move the selection by `step` places (wraps) and show that theme in the shell.
    function move(step: int): void {
        if (!Number.isInteger(step)) throw new Error("invariant: ThemePicker.move: step must be an integer")
        if (!isOpen) throw new Error("invariant: ThemePicker.move: the picker is not open")
        throw new Error("not implemented")
    }

    // Select the entry at `index` and show its theme in the shell (a click or a hover).
    function select(index: int): void {
        if (index < 0 || index >= entries.length) throw new Error("invariant: ThemePicker.select: index outside the entries")
        if (!isOpen) throw new Error("invariant: ThemePicker.select: the picker is not open")
        throw new Error("not implemented")
    }

    // The index in `entries` of a theme id, -1 when it is not there.
    function indexOfTheme(id: string): int {
        throw new Error("not implemented")
    }
}
