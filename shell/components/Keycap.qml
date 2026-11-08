// Keycap: Keycap (03 §9): JetBrains Mono micro, raised, radius 4, 18 high.
// The text as the user reads it: "Super" written out, "⇧", "↵", arrow glyphs.
import QtQuick
import qs.core

Item {
    id: root

    property string text: ""

    implicitHeight: Tokens.keycap.height
    implicitWidth: Math.max(implicitHeight, label.implicitWidth + 2 * Tokens.keycap.padH)
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    Rectangle {
        anchors.fill: parent
        radius: Tokens.keycap.radius
        color: Tokens.raised
    }
    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        type: "micro"
        ink: "sec"
        font.family: Tokens.fontMono
    }
}
