pragma ComponentBehavior: Bound
import QtQuick
import qs.theme
import qs.components

// Editor for the launcher mode keys: tap a row, press the new combination. Esc cancels, a key needs Ctrl, Alt or Meta.
Column {
    id: editor

    property var keys: ({})   // mode name -> key sequence, e.g. { apps: "Ctrl+1" }
    signal changed(var keys)

    readonly property var modes: [
        { name: "apps", title: "Apps", fallback: "Ctrl+1" },
        { name: "web", title: "Web", fallback: "Ctrl+2" },
        { name: "settings", title: "Settings", fallback: "Ctrl+3" },
        { name: "ai", title: "AI", fallback: "Ctrl+4" },
        { name: "clipboard", title: "Clipboard", fallback: "Ctrl+5" }
    ]
    property string capturing   // name of the row waiting for a key, "" if none
    property string hint        // why the last key was refused

    spacing: 4

    function keyOf(name: string): string {
        const m = editor.modes.find(x => x.name === name)
        return (editor.keys && editor.keys[name]) || (m ? m.fallback : "")
    }

    // Names of the other modes that already use this combination.
    function clashes(name: string): var {
        const mine = keyOf(name)
        return editor.modes.filter(m => m.name !== name && keyOf(m.name) === mine).map(m => m.title)
    }

    // Qt key sequence text for a key event, or "" for a bare modifier key.
    function sequenceOf(event: var): string {
        const k = event.key
        let name = ""
        if (k >= Qt.Key_0 && k <= Qt.Key_9 || k >= Qt.Key_A && k <= Qt.Key_Z) name = String.fromCharCode(k)
        else if (k >= Qt.Key_F1 && k <= Qt.Key_F12) name = "F" + (k - Qt.Key_F1 + 1)
        else name = ({
            [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up", [Qt.Key_Down]: "Down",
            [Qt.Key_Tab]: "Tab", [Qt.Key_Space]: "Space", [Qt.Key_Comma]: ",", [Qt.Key_Period]: ".",
            [Qt.Key_Slash]: "/", [Qt.Key_Semicolon]: ";", [Qt.Key_Minus]: "-", [Qt.Key_Plus]: "+"
        })[k] || ""
        if (name === "") return ""
        const m = event.modifiers
        return (m & Qt.ControlModifier ? "Ctrl+" : "") + (m & Qt.AltModifier ? "Alt+" : "")
            + (m & Qt.ShiftModifier ? "Shift+" : "") + (m & Qt.MetaModifier ? "Meta+" : "") + name
    }

    function assign(name: string, sequence: string): void {
        const next = {}
        for (const m of editor.modes) next[m.name] = editor.keyOf(m.name)
        next[name] = sequence
        editor.changed(next)
    }

    Repeater {
        model: editor.modes
        delegate: FocusScope {
            id: line
            required property var modelData
            readonly property bool waiting: editor.capturing === modelData.name
            readonly property var clash: editor.clashes(modelData.name)
            width: editor.width
            height: 44

            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: 120
                text: line.modelData.title
            }
            Item {
                id: slot
                x: 130
                width: 150
                height: 36
                anchors.verticalCenter: parent.verticalCenter
                focus: line.waiting

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Tokens.surfaceAlt
                    border.width: 1
                    border.color: line.waiting ? Tokens.ink : Tokens.line
                }
                Label {
                    anchors.centerIn: parent
                    text: line.waiting ? "Press keys…" : editor.keyOf(line.modelData.name)
                    color: line.waiting ? Tokens.inkSoft : Tokens.ink
                }
                MouseArea {
                    anchors { fill: parent; margins: -2 }
                    onClicked: {
                        editor.hint = ""
                        editor.capturing = line.modelData.name
                        slot.forceActiveFocus()
                    }
                }
                // Without this, the window's Esc and Ctrl+F shortcuts would take the keys.
                Keys.onShortcutOverride: event => { if (line.waiting) event.accepted = true }
                Keys.onPressed: event => {
                    if (!line.waiting) return
                    event.accepted = true
                    if (event.key === Qt.Key_Escape) { editor.capturing = ""; editor.hint = ""; return }
                    const seq = editor.sequenceOf(event)
                    if (seq === "") return
                    if (!(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                        editor.hint = "Use Ctrl, Alt or Meta with the key, plain keys would type into the search."
                        return
                    }
                    editor.capturing = ""
                    editor.hint = ""
                    editor.assign(line.modelData.name, seq)
                }
                onActiveFocusChanged: if (!activeFocus && line.waiting) editor.capturing = ""
            }
            Label {
                visible: line.clash.length > 0
                anchors { left: slot.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: "Also used by " + line.clash.join(", ")
                color: Tokens.warn
            }
        }
    }
    Label {
        visible: editor.hint !== ""
        text: editor.hint
        color: Tokens.inkFaint
    }
}
