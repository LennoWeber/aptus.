pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.services
import qs.components

// Clipboard view: search field and the history from cliphist; Enter or a tap puts the entry back.
FocusScope {
    id: clip

    property string query
    property int selectedIndex
    property var results       // entries of Clipboard that match the query
    property color ink
    property color inkSoft
    property color line

    signal closeRequested()

    // Fill results from Clipboard.entries for the current query.
    function refilter(): void {
        const q = query.trim().toLowerCase()
        const all = Clipboard.entries || []
        results = (q === "" ? all : all.filter(e => e.preview.toLowerCase().indexOf(q) >= 0)).slice(0, 60)
        selectedIndex = Math.min(selectedIndex, Math.max(0, results.length - 1))
    }

    function moveSelection(delta: int): void {
        if (!results || results.length === 0) return
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta))
        list.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    // Put the selected entry back on the clipboard and close.
    function activateSelected(): void {
        if (!results || results.length === 0 || !Clipboard.available) return
        Clipboard.copy(results[selectedIndex].id)
        closeRequested()
    }

    function removeSelected(): void {
        if (!results || results.length === 0 || !Clipboard.available) return
        Clipboard.remove(results[selectedIndex].id)
    }

    function reset(): void {
        query = ""
        selectedIndex = 0
        field.text = ""
        Clipboard.refresh()
        refilter()
        field.forceActiveFocus()
    }

    Connections { target: Clipboard; function onEntriesChanged() { clip.refilter() } }

    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        height: 38
        radius: 19
        color: clip.ink
        opacity: 0.07
    }
    TextInput {
        id: field
        anchors { left: bar.left; right: bar.right; verticalCenter: bar.verticalCenter; leftMargin: 16; rightMargin: 16 }
        color: clip.ink
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.sizeBody
        clip: true
        selectByMouse: true
        focus: true
        onTextChanged: { clip.query = text; clip.selectedIndex = 0; clip.refilter() }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down) { clip.moveSelection(1); event.accepted = true }
            else if (event.key === Qt.Key_Up) { clip.moveSelection(-1); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { clip.activateSelected(); event.accepted = true }
            else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) { clip.removeSelected(); event.accepted = true }
        }
        Label {
            visible: field.text === ""
            anchors.verticalCenter: parent.verticalCenter
            text: Clipboard.available ? "Search the clipboard" : "cliphist is not installed"
            color: clip.inkSoft
        }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: bar.bottom; bottom: parent.bottom; margins: 12; topMargin: 8 }
        clip: true
        model: clip.results
        spacing: 2
        delegate: Item {
            id: row
            required property var modelData
            required property int index
            width: list.width
            height: 36
            readonly property bool isSelected: clip.selectedIndex === index
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: clip.ink
                opacity: rowMouse.pressed ? 0.14 : (rowMouse.containsMouse || row.isSelected) ? 0.08 : 0
            }
            Label {
                anchors { left: parent.left; right: tag.left; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 8 }
                text: row.modelData.preview
                color: clip.ink
                elide: Text.ElideRight
            }
            Label {
                id: tag
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
                visible: row.modelData.kind === "image"
                text: "image"
                role: Enums.TextRole.Bar
                color: clip.inkSoft
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: { clip.selectedIndex = row.index; clip.activateSelected() }
            }
        }
        Label {
            visible: clip.results && clip.results.length === 0
            anchors.centerIn: parent
            text: clip.query === "" ? "Nothing copied yet" : "No match"
            color: clip.inkSoft
        }
    }
}
