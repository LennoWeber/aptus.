pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.models
import qs.theme
import qs.services
import qs.components

// Emoji view: search field and a grid; Enter or a tap copies the emoji.
FocusScope {
    id: emoji

    property string query
    property int selectedIndex
    property var all           // { e, n } of config/emoji.json
    property var results       // the entries that match the query
    property string lastCopied
    property color ink
    property color inkSoft
    property color line

    signal closeRequested()

    readonly property int columns: 10

    FileView {
        id: emojiFile
        path: Tokens.rootDir + "/config/emoji.json"
        blockLoading: true
        printErrors: false
    }

    // Read config/emoji.json into `all`.
    function load(): void {
        if (all && all.length > 0) return
        try {
            all = JSON.parse(emojiFile.text()).emoji
        } catch (e) {
            console.error("aptus: cannot read emoji.json (" + e + ")")
            all = []
        }
    }

    // Fill results from `all` for the current query (every word of the query must appear in the name).
    function refilter(): void {
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w !== "")
        const list = all || []
        results = (words.length === 0 ? list : list.filter(x => words.every(w => x.n.indexOf(w) >= 0))).slice(0, 400)
        selectedIndex = Math.min(selectedIndex, Math.max(0, results.length - 1))
    }

    function moveSelection(deltaColumns: int, deltaRows: int): void {
        if (!results || results.length === 0) return
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + deltaColumns + deltaRows * columns))
        grid.positionViewAtIndex(selectedIndex, GridView.Contain)
    }

    // Copy the selected emoji (wl-copy) and close.
    function activateSelected(): void {
        if (!results || results.length === 0) return
        lastCopied = results[selectedIndex].e
        Quickshell.execDetached(["wl-copy", lastCopied])
        closeRequested()
    }

    function reset(): void {
        load()
        query = ""
        selectedIndex = 0
        field.text = ""
        refilter()
        field.forceActiveFocus()
    }

    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        height: 38
        radius: 19
        color: emoji.ink
        opacity: 0.07
    }
    TextInput {
        id: field
        anchors { left: bar.left; right: bar.right; verticalCenter: bar.verticalCenter; leftMargin: 16; rightMargin: 16 }
        color: emoji.ink
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.sizeBody
        clip: true
        selectByMouse: true
        focus: true
        onTextChanged: { emoji.query = text; emoji.selectedIndex = 0; emoji.refilter() }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down) { emoji.moveSelection(0, 1); event.accepted = true }
            else if (event.key === Qt.Key_Up) { emoji.moveSelection(0, -1); event.accepted = true }
            else if (event.key === Qt.Key_Right && field.cursorPosition === field.length) { emoji.moveSelection(1, 0); event.accepted = true }
            else if (event.key === Qt.Key_Left && field.cursorPosition === 0) { emoji.moveSelection(-1, 0); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { emoji.activateSelected(); event.accepted = true }
        }
        Label {
            visible: field.text === ""
            anchors.verticalCenter: parent.verticalCenter
            text: "Search emoji"
            color: emoji.inkSoft
        }
    }

    GridView {
        id: grid
        anchors { left: parent.left; right: parent.right; top: bar.bottom; bottom: parent.bottom; margins: 12; topMargin: 8 }
        clip: true
        cellWidth: Math.floor(width / emoji.columns)
        cellHeight: 38
        model: emoji.results
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            width: grid.cellWidth
            height: grid.cellHeight
            readonly property bool isSelected: emoji.selectedIndex === index
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 4
                height: parent.height - 2
                radius: 9
                color: emoji.ink
                opacity: cellMouse.pressed ? 0.16 : (cellMouse.containsMouse || cell.isSelected) ? 0.09 : 0
            }
            Text {
                anchors.centerIn: parent
                text: cell.modelData.e
                font.pixelSize: 22
                renderType: Text.NativeRendering
            }
            MouseArea {
                id: cellMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: { emoji.selectedIndex = cell.index; emoji.activateSelected() }
            }
        }
        Label {
            visible: !!emoji.results && emoji.results.length === 0
            anchors.centerIn: parent
            text: "No match"
            color: emoji.inkSoft
        }
    }
}
