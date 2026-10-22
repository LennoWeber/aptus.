import QtQuick
import qs.models
import qs.theme
import qs.components
import qs.services

// Content of the lockscreen on each screen: warm backdrop, big clock, password pill.
// Notification text stays hidden unless the setting allows it; only a count is shown by default.
Item {
    id: surface

    property var lockState  // LockState
    property bool use24h: true
    property var now: new Date()
    property real blurRadius
    property bool showClock: true

    readonly property bool touchKeyboard: lockState && lockState.keyboardVisible

    function focusPassword(): void { pill.focusInput() }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Tokens.bg }
            GradientStop { position: 1; color: Tokens.surfaceAlt }
        }
    }

    Image {
        anchors.fill: parent
        visible: Wallpaper.current !== ""
        source: Wallpaper.current ? "file://" + Wallpaper.current : ""
        sourceSize: Qt.size(parent.width, parent.height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.durSlow } }
    }
    // A light veil keeps the clock and the pill readable on any picture.
    Rectangle {
        anchors.fill: parent
        visible: Wallpaper.current !== ""
        // TODO(phase 7, Bild-Theming): the veil over the wallpaper uses Tokens.glass; Tokens.grain on the large surface. The lockscreen follows the user's style.
        color: Tokens.bg
        opacity: 0.45
    }

    Label {
        x: 28
        y: 20
        text: "shell."
        font.weight: Font.DemiBold
        font.pixelSize: 16
    }

    Item {
        id: stage
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        // The clock and pill move up when the keyboard needs room.
        y: surface.touchKeyboard ? parent.height * 0.08 : parent.height * 0.26
        Behavior on y { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

        ClockBlock {
            id: clock
            visible: surface.showClock
            anchors.horizontalCenter: parent.horizontalCenter
            use24h: surface.use24h
            now: surface.now
        }

        PasswordPill {
            id: pill
            anchors { horizontalCenter: parent.horizontalCenter; top: clock.bottom; topMargin: 44 }
            busy: surface.lockState ? surface.lockState.authenticating : false
            error: surface.lockState ? surface.lockState.message !== "" : false
            placeholder: busy ? "Checking…" : "Enter password"
            onSubmitted: surface.submit(pill.text)
            onTextEdited: if (surface.lockState.message !== "") surface.lockState.message = ""
        }

        Label {
            id: message
            anchors { horizontalCenter: parent.horizontalCenter; top: pill.bottom; topMargin: 14 }
            text: surface.lockState ? surface.lockState.message : ""
            tone: Enums.Severity.Critical
        }

        // Only a count by default; the text of notifications stays private.
        Label {
            anchors { horizontalCenter: parent.horizontalCenter; top: message.bottom; topMargin: 22 }
            visible: Notifications.unreadCount > 0
            text: Notifications.unreadCount + (Notifications.unreadCount === 1 ? " notification" : " notifications")
                + (surface.lockState && surface.lockState.showNotificationContent && Notifications.items.length > 0 ? ": " + Notifications.items[0].summary : "")
            color: Tokens.inkSoft
        }
    }

    // Touch: the built-in keyboard, so the tablet mode never locks you out.
    OnScreenKeyboard {
        id: keyboard
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 36 }
        width: Math.min(parent.width - 40, 820)
        opacity: surface.touchKeyboard ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
        onKeyPressed: key => pill.insert(key)
        onBackspace: pill.backspace()
        onEnter: surface.submit(pill.text)
        onShiftToggled: keyboard.shifted = !keyboard.shifted
    }

    ActionButton {
        anchors { right: parent.right; rightMargin: 28; bottom: parent.bottom; bottomMargin: 24 }
        visible: surface.lockState && surface.lockState.keyboardMode !== "never" && !surface.touchKeyboard
        implicitHeight: 44
        text: "Keyboard"
        onClicked: surface.lockState.setKeyboardVisible(true)
    }
    ActionButton {
        anchors { right: parent.right; rightMargin: 28; top: parent.top; topMargin: 16 }
        visible: surface.touchKeyboard && surface.lockState.keyboardMode !== "always"
        implicitHeight: 44
        text: "Hide keyboard"
        onClicked: surface.lockState.setKeyboardVisible(false)
    }

    // A touch anywhere brings the keyboard up in auto mode.
    TapHandler {
        acceptedDevices: PointerDevice.TouchScreen
        onTapped: if (surface.lockState.keyboardMode === "auto") surface.lockState.setKeyboardVisible(true)
    }

    function submit(text: string): void {
        if (!lockState || lockState.authenticating || text === "") return
        lockState.setPassword(text)
        pill.clear()
        lockState.tryUnlock()
    }

    Connections {
        target: surface.lockState
        function onMessageChanged() { if (surface.lockState.message !== "") { pill.shake(); pill.focusInput() } }
        function onLockedChanged() { if (surface.lockState.locked) { pill.clear(); pill.focusInput() } }
    }

    Keys.onEscapePressed: pill.clear()
    Component.onCompleted: pill.focusInput()
}
