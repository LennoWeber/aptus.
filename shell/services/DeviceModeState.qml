import QtQuick

// Laptop / tablet state of the 2-in-1.
QtObject {
    property bool tabletMode         // tablet switch reported by the device
    property bool keyboardAttached
    property bool lidClosed
    property bool touchActive        // last input came from the touchscreen
    property bool onScreenKeyboardVisible
    property int orientation         // Enums.Orientation, from the orientation sensor
    property bool autoRotate         // follow the sensor in tablet mode
    property bool rotationLocked     // user locked the current orientation

    function setAutoRotate(on: bool): void {
        // TODO(phase 7): Compositor.setMonitorTransform in tablet mode only; lockscreen and greeter follow the orientation.
        throw new Error("not implemented")
    }

    function setRotationLocked(on: bool): void {
        throw new Error("not implemented")
    }

    function showKeyboard(): void {
        // TODO(phase 7): built-in keyboard on lockscreen and greeter; a system keyboard only if one is installed.
        throw new Error("not implemented")
    }

    function hideKeyboard(): void {
        throw new Error("not implemented")
    }
}
