import QtQuick
import Quickshell
import qs.models
import qs.theme
import qs.services
import qs.components

// Emoji view: search field and a grid; Enter or a tap copies the emoji.
FocusScope {
    id: emoji

    property string query
    property int selectedIndex
    property var all: []       // { e, n } of config/emoji.json
    property var results: []   // the entries that match the query
    property string lastCopied
    property color ink
    property color inkSoft
    property color line

    signal closeRequested()

    FileView {
        id: emojiFile
        path: Tokens.rootDir + "/config/emoji.json"
        blockLoading: true
        printErrors: false
    }

    readonly property int columns: 10

    // Read config/emoji.json into `all`.
    function load(): void {
        throw new Error("not implemented")
    }

    // Fill results from `all` for the current query (every word of the query must appear in the name).
    function refilter(): void {
        throw new Error("not implemented")
    }

    function moveSelection(deltaColumns: int, deltaRows: int): void {
        throw new Error("not implemented")
    }

    // Copy the selected emoji (wl-copy) and close.
    function activateSelected(): void {
        throw new Error("not implemented")
    }

    function reset(): void {
        throw new Error("not implemented")
    }
}
