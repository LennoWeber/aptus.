pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components
import qs.services

// One setting: title and description on the left, the editor on the right.
Item {
    id: row

    property var entry              // schema entry
    property var draftValue         // value shown now (draft if there is one)
    property bool changed           // differs from the value in effect
    property bool isDefault: true
    property bool editable: true
    property bool highlighted
    property var choices: []        // choice entries: list of { id, label }
    property string actionLabel: "Run"
    signal valueEdited(var value)
    signal resetRequested()
    signal actionRequested()

    // Lists and the location have a tall editor under the title; everything else sits to the right of it.
    readonly property bool wide: !!entry && (entry.kind === "list" || entry.kind === "location" || entry.kind === "providerList" || entry.kind === "hotkeyList" || entry.kind === "tileList" || entry.kind === "keyMap")

    implicitHeight: wide ? textColumn.implicitHeight + wideEditor.implicitHeight + 44 : Math.max(64, textColumn.implicitHeight + 28)

    function nudge(delta: real): void {
        const step = entry && entry.step ? entry.step : 1
        const lo = entry.min !== undefined ? entry.min : -Infinity
        const hi = entry.max !== undefined ? entry.max : Infinity
        valueEdited(Math.max(lo, Math.min(hi, (Number(draftValue) || 0) + delta * step)))
    }

    Rectangle {
        anchors { fill: parent; topMargin: 2; bottomMargin: 2 }
        radius: 10
        color: Tokens.ink
        opacity: row.highlighted ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.durSlow } }
    }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Tokens.line; opacity: 0.6 }

    Column {
        id: textColumn
        anchors { left: parent.left; leftMargin: 4; right: editor.left; rightMargin: 20; verticalCenter: row.wide ? undefined : parent.verticalCenter; top: row.wide ? parent.top : undefined; topMargin: 16 }
        spacing: 3
        Row {
            spacing: 8
            Label { text: row.entry ? row.entry.title : ""; font.weight: Font.Medium }
            Label { visible: row.changed; text: "Changed"; role: Enums.TextRole.Bar; color: Tokens.inkFaint; anchors.verticalCenter: parent.verticalCenter }
        }
        Label {
            visible: !!row.entry && !!row.entry.description
            width: parent.width
            text: row.entry && row.entry.description ? row.entry.description : ""
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
            wrapMode: Text.Wrap
        }
        Label {
            visible: row.entry && !row.editable && row.entry.kind !== "action" && !row.wide
            width: parent.width
            text: "Edit this in ~/.config/aptus/settings.json for now."
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }
    }

    Loader {
        id: wideEditor
        visible: row.wide
        anchors { left: parent.left; leftMargin: 4; right: parent.right; top: textColumn.bottom; topMargin: 14 }
        sourceComponent: row.entry && row.entry.kind === "list" ? engineEditor : row.entry && row.entry.kind === "location" ? locationEditor : row.entry && row.entry.kind === "providerList" ? providerEditor : row.entry && row.entry.kind === "hotkeyList" ? hotkeyList : row.entry && row.entry.kind === "tileList" ? tileEditor : row.entry && row.entry.kind === "keyMap" ? modeKeyEditor : null
    }
    Component {
        id: engineEditor
        SearchEngineEditor { engines: row.draftValue || []; onChanged: value => row.valueEdited(value) }
    }
    Component {
        id: tileEditor
        TileListEditor { tiles: row.draftValue; onChanged: value => row.valueEdited(value) }
    }
    Component {
        id: modeKeyEditor
        ModeKeyEditor { keys: row.draftValue || ({}); onChanged: value => row.valueEdited(value) }
    }
    Component {
        id: hotkeyList
        HotkeyList {}
    }
    Component {
        id: providerEditor
        ProviderEditor {}
    }
    Component {
        id: locationEditor
        LocationEditor { weather: row.draftValue || ({}); onChanged: value => row.valueEdited(value) }
    }

    Row {
        id: editor
        anchors { right: parent.right; rightMargin: 4; verticalCenter: row.wide ? undefined : parent.verticalCenter; top: row.wide ? parent.top : undefined; topMargin: 16 }
        spacing: 10

        // Back to the default, only while it differs.
        Label {
            visible: row.editable && !row.isDefault
            anchors.verticalCenter: parent.verticalCenter
            text: "Reset"
            role: Enums.TextRole.Bar
            color: resetArea.containsMouse ? Tokens.ink : Tokens.inkFaint
            MouseArea { id: resetArea; anchors { fill: parent; margins: -8 } hoverEnabled: true; onClicked: row.resetRequested() }
        }

        ToggleSwitch {
            visible: row.entry && row.entry.kind === "toggle"
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 40
            width: 40
            checked: !!row.draftValue
            onToggled: value => row.valueEdited(value)
        }

        // Choices as a row of small pills.
        Row {
            visible: row.entry && row.entry.kind === "choice"
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Repeater {
                model: row.choices
                delegate: Item {
                    id: opt
                    required property var modelData
                    readonly property bool on: opt.modelData.id === row.draftValue
                    width: optLabel.implicitWidth + 24
                    height: 30
                    Rectangle {
                        anchors.fill: parent
                        radius: 15
                        color: opt.on ? Tokens.ink : Tokens.surfaceAlt
                        opacity: opt.on ? 1 : optArea.containsMouse ? 1 : 0.7
                        border.width: opt.on ? 0 : 1
                        border.color: Tokens.line
                        Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                    }
                    Label { id: optLabel; anchors.centerIn: parent; text: opt.modelData.label; color: opt.on ? Tokens.bg : Tokens.ink; role: Enums.TextRole.Bar }
                    MouseArea { id: optArea; anchors.fill: parent; hoverEnabled: true; onClicked: row.valueEdited(opt.modelData.id) }
                }
            }
        }

        Row {
            visible: row.entry && row.entry.kind === "slider"
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            SliderControl {
                width: 200
                from: row.entry && row.entry.min !== undefined ? row.entry.min : 0
                to: row.entry && row.entry.max !== undefined ? row.entry.max : 1
                step: row.entry && row.entry.step ? row.entry.step : 0
                value: Number(row.draftValue) || 0
                onMoved: value => row.valueEdited(value)
            }
            Label { anchors.verticalCenter: parent.verticalCenter; width: 28; text: String(Math.round(Number(row.draftValue) || 0)); tabularNumbers: true; color: Tokens.inkSoft }
        }

        // Number: minus, value with unit, plus.
        Row {
            visible: row.entry && row.entry.kind === "number"
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Repeater {
                model: [-1, 1]
                delegate: Item {
                    id: nudgeBtn
                    required property int modelData
                    width: 30
                    height: 30
                    Rectangle { anchors.fill: parent; radius: 8; color: Tokens.surfaceAlt; border.width: 1; border.color: Tokens.line; opacity: nudgeArea.pressed ? 1 : nudgeArea.containsMouse ? 0.9 : 0.6 }
                    Label { anchors.centerIn: parent; text: nudgeBtn.modelData < 0 ? "−" : "+" }
                    MouseArea { id: nudgeArea; anchors.fill: parent; hoverEnabled: true; onClicked: row.nudge(nudgeBtn.modelData) }
                }
            }
        }
        Label {
            visible: row.entry && row.entry.kind === "number"
            anchors.verticalCenter: parent.verticalCenter
            text: (row.draftValue !== undefined ? row.draftValue : "") + (row.entry && row.entry.unit ? " " + row.entry.unit : "")
            tabularNumbers: true
        }

        Item {
            visible: row.entry && row.entry.kind === "text"
            anchors.verticalCenter: parent.verticalCenter
            width: 260
            height: 34
            Surface { anchors.fill: parent; cornerRadius: 8 }
            TextInput {
                id: valueInput
                anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                font.family: Tokens.fontUi
                font.pixelSize: 14
                color: Tokens.ink
                clip: true
                echoMode: row.entry && row.entry.secret ? TextInput.Password : TextInput.Normal
                text: row.draftValue === undefined || row.draftValue === null ? "" : String(row.draftValue)
                onTextEdited: row.valueEdited(text)
                onActiveFocusChanged: Osk.track(valueInput, activeFocus)
            }
        }

        ActionButton {
            visible: row.entry && row.entry.kind === "action"
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 34
            text: row.actionLabel
            onClicked: row.actionRequested()
        }
    }
}
