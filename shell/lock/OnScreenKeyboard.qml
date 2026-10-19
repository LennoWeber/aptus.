pragma ComponentBehavior: Bound
import QtQuick
import qs.theme
import qs.components

// Built-in keyboard for lockscreen and greeter (German layout), so the tablet mode never locks you out.
Item {
    id: kb

    property bool shifted
    property bool symbols
    property string layout: "de"
    signal keyPressed(string key)
    signal backspace()
    signal enter()
    signal shiftToggled()

    readonly property var letters: ["1234567890ß", "qwertzuiopü", "asdfghjklöä", "yxcvbnm,.-"]
    readonly property var symbolRows: ["!\"§$%&/()=?", "@#€_+*~<>|\\", "[]{}^°'`´;:", "…µ²³¿¡«»„“"]
    readonly property var rows: symbols ? symbolRows : letters
    readonly property real keyW: Math.min(62, (width - 10 * 6) / 11)

    implicitWidth: 760
    implicitHeight: 5 * 52 + 4 * 6

    function showKeyboard(): void { visible = true }
    function hideKeyboard(): void { visible = false }

    function label(ch: string): string {
        return shifted && !symbols ? ch.toUpperCase() : ch
    }

    Column {
        width: parent.width
        spacing: 6

        Repeater {
            model: kb.rows
            delegate: Row {
                id: line
                required property string modelData
                x: (kb.width - width) / 2
                spacing: 6
                Repeater {
                    model: line.modelData.split("")
                    delegate: Key {
                        required property string modelData
                        width: kb.keyW
                        text: kb.label(modelData)
                        onTapped: {
                            kb.keyPressed(text)
                            if (kb.shifted) kb.shiftToggled()
                        }
                    }
                }
            }
        }
        Row {
            x: (kb.width - width) / 2
            spacing: 6
            Key { width: kb.keyW * 1.6; text: kb.symbols ? "abc" : "123"; onTapped: kb.symbols = !kb.symbols }
            Key { width: kb.keyW * 1.6; text: "⇧"; active: kb.shifted; onTapped: kb.shiftToggled() }
            Key { width: kb.keyW * 4.5; text: "space"; onTapped: kb.keyPressed(" ") }
            Key { width: kb.keyW * 1.6; text: "⌫"; onTapped: kb.backspace() }
            Key { width: kb.keyW * 1.6; text: "Enter"; primary: true; onTapped: kb.enter() }
        }
    }

    // One key: a large target, instant pressed state.
    component Key: Item {
        id: key
        property string text
        property bool active
        property bool primary
        signal tapped()
        height: 52
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: key.primary || key.active ? Tokens.ink : Tokens.surface
            border.width: 1
            border.color: Tokens.line
            opacity: area.pressed ? 0.7 : 1
        }
        Label {
            anchors.centerIn: parent
            text: key.text
            font.pixelSize: 18
            color: key.primary || key.active ? Tokens.bg : Tokens.ink
        }
        MouseArea { id: area; anchors.fill: parent; onClicked: key.tapped() }
    }
}
