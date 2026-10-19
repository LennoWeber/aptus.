import QtQuick
import qs.models
import qs.theme
import qs.components

// What the launcher shows before typing: one quiet line.
Item {
    id: empty

    property string hint

    implicitHeight: 24

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        text: empty.hint
        role: Enums.TextRole.Bar
        color: Tokens.inkFaint
    }
}
