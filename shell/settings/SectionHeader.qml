import QtQuick
import qs.models
import qs.theme
import qs.components

// Sub-heading inside a category page: a small title over a quiet rule.
Item {
    id: header

    property string title
    property bool first                // the first heading of a page needs less air above it

    implicitHeight: first ? 34 : 54

    Label {
        anchors { left: parent.left; leftMargin: 4; bottom: parent.bottom; bottomMargin: 8 }
        text: header.title
        role: Enums.TextRole.Bar
        font.weight: Font.DemiBold
        color: Tokens.inkSoft
    }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Tokens.line }
}
