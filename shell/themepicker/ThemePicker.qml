pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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
    Behavior on reveal { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

    screen: {
        const m = Hyprland.focusedMonitor
        if (m) for (const s of Quickshell.screens) if (s.name === m.name) return s
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }
    visible: isOpen || reveal > 0.001
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aptus-theme-picker"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Open on the focused screen with the theme in effect selected, remember it as startThemeId.
    function show(): void {
        if (entries.length === 0) throw new Error("invariant: ThemePicker.show: Tokens.themeList is empty (tokens not loaded)")
        if (!themeState) throw new Error("invariant: ThemePicker.show: themeState not set")
        startThemeId = themeState.resolved
        selectedIndex = Math.max(0, indexOfTheme(startThemeId))
        isOpen = true
        keys.forceActiveFocus()
    }

    // Close. `keep` true keeps the selected theme (commit), false puts the starting theme back.
    function hide(keep: bool): void {
        if (!themeState) throw new Error("invariant: ThemePicker.hide: themeState not set")
        if (!isOpen) return
        isOpen = false
        const chosen = entries[selectedIndex] ? entries[selectedIndex].id : startThemeId
        // Keeping what was showing at the start changes nothing, so an "auto" setting stays "auto".
        if (keep && chosen !== startThemeId) themeState.commitPreview()
        else themeState.cancelPreview()
    }

    // Super+T: open when closed, else move on to the next theme.
    function toggle(): void {
        if (!isOpen) {
            show()
            return
        }
        move(1)
    }

    // Move the selection by `step` places (wraps) and show that theme in the shell.
    function move(step: int): void {
        if (!Number.isInteger(step)) throw new Error("invariant: ThemePicker.move: step must be an integer")
        if (!isOpen) throw new Error("invariant: ThemePicker.move: the picker is not open")
        if (entries.length === 0) return
        select(((selectedIndex + step) % entries.length + entries.length) % entries.length)
    }

    // Select the entry at `index` and show its theme in the shell (a click or a hover).
    function select(index: int): void {
        if (!isOpen) throw new Error("invariant: ThemePicker.select: the picker is not open")
        if (index < 0 || index >= entries.length) throw new Error("invariant: ThemePicker.select: index outside the entries")
        selectedIndex = index
        if (entries[index].id === startThemeId) themeState.cancelPreview()
        else themeState.preview(entries[index].id)
    }

    // The index in `entries` of a theme id, -1 when it is not there.
    function indexOfTheme(id: string): int {
        return entries.findIndex(e => e.id === id)
    }

    // A click outside the card keeps the choice.
    MouseArea {
        anchors.fill: parent
        onClicked: picker.hide(true)
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: picker.isOpen
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab || event.key === Qt.Key_Up) { picker.move(-1); event.accepted = true }
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key === Qt.Key_Down) { picker.move(1); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { picker.hide(true); event.accepted = true }
            else if (event.key === Qt.Key_Escape) { picker.hide(false); event.accepted = true }
            else if (event.key === Qt.Key_T && (event.modifiers & Qt.MetaModifier)) { picker.move(1); event.accepted = true }
        }
    }

    Surface {
        id: card
        x: (parent.width - width) / 2
        y: Tokens.topInset + 14 - 10 * (1 - picker.reveal)
        width: row.implicitWidth + 40
        height: row.implicitHeight + 64
        opacity: picker.reveal
        elevated: true
        cornerRadius: Tokens.radiusTile

        Label {
            x: 20
            y: 14
            text: "Theme"
            font.weight: Font.DemiBold
        }
        Label {
            anchors { right: parent.right; rightMargin: 20; top: parent.top; topMargin: 14 }
            text: "← →  choose     Enter  keep     Esc  back"
            color: Tokens.inkFaint
        }
        Row {
            id: row
            x: 20
            y: 44
            spacing: 12
            Repeater {
                model: picker.entries
                delegate: ThemeSwatch {
                    required property var modelData
                    required property int index
                    themeId: modelData.id
                    label: modelData.name
                    colors: modelData
                    selected: modelData.id === picker.startThemeId
                    highlighted: index === picker.selectedIndex
                    busy: modelData.pending === true
                    onChosen: { picker.select(index); picker.hide(true) }
                }
            }
        }
    }
}
