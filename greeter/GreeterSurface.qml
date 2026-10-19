import QtQuick
import qs.models
import qs.theme
import qs.components
import qs.lock

// The login screen: same look as the lockscreen. User, password pill, session, power buttons, built-in keyboard.
Item {
    id: surface

    property var greeterState  // GreeterState
    property bool use24h: true
    property var now: new Date()

    readonly property bool touchKeyboard: greeterState ? greeterState.keyboardVisible : false

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Tokens.bg }
            GradientStop { position: 1; color: Tokens.surfaceAlt }
        }
    }
    Image {
        anchors.fill: parent
        visible: status !== Image.Null
        source: surface.greeterState && surface.greeterState.wallpaper ? "file://" + surface.greeterState.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.durSlow } }
    }
    Rectangle {
        anchors.fill: parent
        visible: surface.greeterState && surface.greeterState.wallpaper !== ""
        color: Tokens.bg
        opacity: 0.55
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
        y: surface.touchKeyboard ? parent.height * 0.06 : parent.height * 0.22
        Behavior on y { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

        ClockBlock {
            id: clock
            visible: surface.greeterState ? surface.greeterState.showClock : true
            anchors.horizontalCenter: parent.horizontalCenter
            use24h: surface.use24h
            now: surface.now
        }

        UserPicker {
            id: userPicker
            anchors { horizontalCenter: parent.horizontalCenter; top: clock.visible ? clock.bottom : parent.top; topMargin: 30 }
            users: surface.greeterState ? surface.greeterState.users : []
            selectedUser: surface.greeterState ? surface.greeterState.selectedUser : ""
            onUserSelected: name => { surface.greeterState.selectUser(name); pill.clear(); pill.focusInput() }
        }

        PasswordPill {
            id: pill
            anchors { horizontalCenter: parent.horizontalCenter; top: userPicker.bottom; topMargin: 14 }
            busy: surface.greeterState ? surface.greeterState.authenticating : false
            error: surface.greeterState ? surface.greeterState.message !== "" : false
            placeholder: busy ? "Signing in…" : "Enter password"
            onSubmitted: surface.submit(pill.text)
            onTextEdited: if (surface.greeterState.message !== "") surface.greeterState.message = ""
        }

        Label {
            anchors { horizontalCenter: parent.horizontalCenter; top: pill.bottom; topMargin: 14 }
            text: surface.greeterState ? surface.greeterState.message : ""
            tone: Enums.Severity.Critical
        }

        SessionPicker {
            anchors { horizontalCenter: parent.horizontalCenter; top: pill.bottom; topMargin: 44 }
            sessions: surface.greeterState ? surface.greeterState.sessions : []
            selectedSession: surface.greeterState ? surface.greeterState.selectedSession : ""
            onSessionSelected: id => surface.greeterState.selectSession(id)
        }
    }

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

    PowerButtons {
        anchors { left: parent.left; leftMargin: 28; bottom: parent.bottom; bottomMargin: 24 }
        visible: surface.greeterState ? surface.greeterState.showPowerButtons && !surface.touchKeyboard : false
        onActionRequested: action => surface.greeterState.powerAction(action)
    }

    ActionButton {
        anchors { right: parent.right; rightMargin: 28; bottom: parent.bottom; bottomMargin: 24 }
        visible: surface.greeterState && surface.greeterState.keyboardMode !== "never" && !surface.touchKeyboard
        implicitHeight: 44
        text: "Keyboard"
        onClicked: surface.greeterState.setKeyboardVisible(true)
    }
    ActionButton {
        anchors { right: parent.right; rightMargin: 28; top: parent.top; topMargin: 16 }
        visible: surface.touchKeyboard && surface.greeterState.keyboardMode !== "always"
        implicitHeight: 44
        text: "Hide keyboard"
        onClicked: surface.greeterState.setKeyboardVisible(false)
    }

    TapHandler {
        acceptedDevices: PointerDevice.TouchScreen
        onTapped: if (surface.greeterState.keyboardMode === "auto") surface.greeterState.setKeyboardVisible(true)
    }

    function submit(text: string): void {
        if (!greeterState || greeterState.authenticating || text === "") return
        pill.clear()
        greeterState.submit(text)
    }

    Connections {
        target: surface.greeterState
        function onMessageChanged() { if (surface.greeterState.message !== "") { pill.shake(); pill.focusInput() } }
    }

    Keys.onEscapePressed: pill.clear()
    Component.onCompleted: pill.focusInput()
}
