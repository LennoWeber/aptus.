import QtQuick
import qs.models
import qs.theme
import qs.components

// What the launcher shows before typing: one quiet line.
Item {
    id: empty

    property var recentApps
    property var openWindows
    property bool showRecent
    property bool showWindows
    property string hint
    signal appClicked(string appId)
    signal windowClicked(string address)
    // TODO(phase 7, section 3): recent apps row and narrow window cards (showRecent / showWindows).

    implicitHeight: 24

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        text: empty.hint
        role: Enums.TextRole.Bar
        color: Tokens.inkFaint
    }
}
