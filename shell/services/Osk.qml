pragma Singleton
import QtQuick

// Built-in on-screen keyboard for text fields outside the lockscreen. A field reports its focus here; the keyboard
// window types into the field that has it. The keyboard shows in tablet mode (when enabled) or when asked for.
QtObject {
    id: root

    property bool tabletMode      // set from DeviceModeState
    property bool autoShow: true  // settings: touch.autoOnScreenKeyboard
    property bool forced          // IPC osk-toggle: show whenever a field has focus
    property var target           // the TextInput that has the focus
    property var targetWindow     // the window that holds the field
    property var hosts: []        // windows that draw the keyboard themselves (they are full-screen overlays that would cover it)
    property bool dismissed       // the keyboard was closed with its own key; the next focused field shows it again

    readonly property bool shown: target !== null && !dismissed && (forced || (tabletMode && autoShow))

    // Called from a TextInput's onActiveFocusChanged.
    function track(input: var, focused: bool): void {
        if (focused) { target = input; targetWindow = input.Window.window; dismissed = false }
        else if (target === input) target = null
    }

    function registerHost(window: var): void {
        if (hosts.indexOf(window) < 0) hosts.push(window)
    }

    // True when the field's own window draws the keyboard.
    function hostedBy(window: var): bool {
        return shown && targetWindow === window
    }

    function toggleForced(): void {
        forced = !forced
        dismissed = false
    }

    function dismiss(): void {
        dismissed = true
    }

    function type(text: string): void {
        if (!target) return
        const input = target
        input.remove(input.selectionStart, input.selectionEnd)
        input.insert(input.cursorPosition, text)
        input.textEdited()
    }

    function backspace(): void {
        if (!target) return
        const input = target
        if (input.selectionStart !== input.selectionEnd) input.remove(input.selectionStart, input.selectionEnd)
        else if (input.cursorPosition > 0) input.remove(input.cursorPosition - 1, input.cursorPosition)
        input.textEdited()
    }

    function enter(): void {
        if (target) target.accepted()
    }
}
