import QtQuick
import qs.models
import qs.theme
import qs.services
import qs.components

// Emoji view: search field and a grid; Enter or a tap copies the emoji.
Item {
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
}
