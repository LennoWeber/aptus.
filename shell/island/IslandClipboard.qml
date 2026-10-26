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
}
