import QtQuick
import qs.models
import qs.theme
import qs.services
import qs.components

// Clipboard view: search field and the history from cliphist; Enter or a tap puts the entry back.
Item {
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
        throw new Error("not implemented")
    }

    function moveSelection(delta: int): void {
        throw new Error("not implemented")
    }

    // Put the selected entry back on the clipboard and close.
    function activateSelected(): void {
        throw new Error("not implemented")
    }

    function removeSelected(): void {
        throw new Error("not implemented")
    }

    function reset(): void {
        throw new Error("not implemented")
    }
}
