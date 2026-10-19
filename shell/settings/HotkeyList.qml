pragma ComponentBehavior: Bound
import QtQuick
import qs.theme
import qs.models
import qs.components
import qs.services

// The shortcut table, read-only: which keys do what, and which of them clash.
Column {
    id: list

    spacing: 0

    Label {
        width: parent.width
        wrapMode: Text.Wrap
        text: "Yours are set in ~/.config/hypr/hyprland.lua, aptus's own in hypr/binds.generated.lua."
        color: Tokens.inkFaint
        bottomPadding: 8
    }

    Repeater {
        model: Hotkeys.bindings
        delegate: Item {
            id: line
            required property var modelData
            readonly property var clash: Hotkeys.conflicts[modelData.id]
            width: list.width
            height: 36

            Label { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: line.modelData.label }
            Label {
                visible: !!line.clash
                anchors { right: combo.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
                text: line.clash ? "also " + line.clash.join(", ") : ""
                tone: Enums.Severity.Warn
            }
            Label {
                id: combo
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: Hotkeys.combo(line.modelData)
                color: Tokens.inkSoft
            }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Tokens.line; opacity: 0.5 }
        }
    }
}
