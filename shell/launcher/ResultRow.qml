import QtQuick
import Quickshell
import qs.models
import qs.theme
import qs.components

// One result row.
Item {
    id: row

    property var result  // SearchResult
    property bool selected
    signal clicked()

    implicitHeight: 44

    // Apps show their icon; the other kinds get a small mark.
    Item {
        id: iconSlot
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24

        Image {
            visible: row.result && row.result.kind === Enums.ResultKind.App
            anchors.fill: parent
            sourceSize: Qt.size(48, 48)
            source: row.result && row.result.iconName ? Quickshell.iconPath(row.result.iconName, true) : ""
            asynchronous: true
            fillMode: Image.PreserveAspectFit
        }
        ModeGlyph {
            visible: row.result && row.result.kind === Enums.ResultKind.WebSuggestion
            anchors.centerIn: parent
            mode: Enums.LauncherMode.Web
            color: Tokens.inkSoft
        }
        Label {
            visible: row.result && row.result.kind === Enums.ResultKind.Calculation
            anchors.centerIn: parent
            text: "="
            role: Enums.TextRole.Title
            color: Tokens.inkSoft
        }
    }

    Label {
        id: title
        anchors { left: iconSlot.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
        width: Math.min(implicitWidth, row.width - 220)
        elide: Text.ElideRight
        text: row.result ? row.result.title : ""
        color: Tokens.ink
        font.weight: row.selected ? Font.Medium : Font.Normal
    }

    Label {
        anchors { left: title.right; leftMargin: 10; right: hint.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
        elide: Text.ElideRight
        text: row.result ? row.result.subtitle : ""
        role: Enums.TextRole.Bar
        color: Tokens.inkFaint
    }

    Label {
        id: hint
        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        text: row.selected && row.result ? (row.result.keyHint || "Enter") : ""
        role: Enums.TextRole.Bar
        color: Tokens.inkFaint
    }

    MouseArea {
        anchors.fill: parent
        onClicked: row.clicked()
    }
}
