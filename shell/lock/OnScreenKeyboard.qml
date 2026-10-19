import QtQuick

// Built-in on-screen keyboard for lockscreen and greeter.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): small and plain, large keys; appears in tablet mode or after a touch (AppSettings.lockKeyboardMode).

    property bool shifted
    property string layout
    signal keyPressed(string key)
    signal backspace()
    signal enter()
    signal shiftToggled()

    function showKeyboard(): void {
        throw new Error("not implemented")
    }

    function hideKeyboard(): void {
        throw new Error("not implemented")
    }
}
