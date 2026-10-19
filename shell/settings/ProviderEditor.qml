pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.theme
import qs.models
import qs.components
import qs.services

// AI providers: switch on and off, remove own ones, add a command-line tool. Applies at once (own file).
Column {
    id: editor

    property string error
    property string testResult

    Process {
        id: finder
        stdout: StdioCollector {
            onStreamFinished: editor.testResult = text.trim() === "" ? editor.testResult + ": not found in PATH" : editor.testResult + ": found at " + text.trim()
        }
    }
    function testCommand(name: string, command: string): void {
        testResult = name
        finder.command = ["sh", "-c", "PATH=\"$HOME/.local/bin:$PATH\"; command -v \"$1\"", "sh", command]
        finder.running = true
    }

    spacing: 8

    function addProvider(): void {
        const name = nameField.text.trim()
        const command = commandField.text.trim()
        const args = argsField.text.trim().split(/\s+/).filter(a => a !== "")
        const id = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
        if (!name || !command) { error = "Give it a name and a command."; return }
        if (command.indexOf(" ") >= 0) { error = "The command is one program; put its options under Arguments."; return }
        if (args.filter(a => a === "{prompt}").length !== 1) { error = "Arguments must contain {prompt} exactly once."; return }
        if (AiProviders.find(id)) { error = "A provider with this name exists."; return }
        error = ""
        AiProviders.add({ id: id, name: name, command: command, quickArgs: args })
        nameField.text = ""
        commandField.text = ""
        argsField.text = ""
    }

    Repeater {
        model: AiProviders.providers
        delegate: Item {
            id: line
            required property var modelData
            width: editor.width
            height: 40

            Label {
                id: nameLabel
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: line.modelData.name
                font.weight: Font.Medium
            }
            Label {
                anchors { left: nameLabel.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                text: line.modelData.command + (line.modelData.builtIn ? "" : "  ·  yours")
                color: Tokens.inkFaint
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 12
                ActionButton {
                    implicitHeight: 30
                    text: "Test"
                    onClicked: editor.testCommand(line.modelData.name, line.modelData.command)
                }
                ActionButton {
                    visible: !line.modelData.builtIn
                    implicitHeight: 30
                    text: "Remove"
                    onClicked: AiProviders.remove(line.modelData.id)
                }
                ToggleSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 40
                    width: 40
                    checked: line.modelData.enabled
                    onToggled: value => {
                        try { AiProviders.setEnabled(line.modelData.id, value); editor.error = "" } catch (e) { editor.error = "At least one provider has to stay on." }
                    }
                }
            }
        }
    }

    Label { visible: editor.testResult !== ""; text: editor.testResult; color: Tokens.inkSoft }
    Label { text: "Add a command-line tool"; color: Tokens.inkSoft }
    Row {
        spacing: 8
        FieldBox { id: nameField; width: 130; placeholder: "Name" }
        FieldBox { id: commandField; width: 130; placeholder: "Command, e.g. gemini" }
        FieldBox { id: argsField; width: 250; placeholder: "Arguments, e.g. -p {prompt}"; onAccepted: editor.addProvider() }
        ActionButton { implicitHeight: 34; text: "Add"; onClicked: editor.addProvider() }
    }
    Label { visible: editor.error !== ""; text: editor.error; tone: Enums.Severity.Critical }
}
