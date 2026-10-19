import QtQuick
import qs.theme
import qs.components

// The session, small and quiet. With several sessions a tap goes to the next one.
Item {
    id: picker

    property var sessions: []
    property string selectedSession
    signal sessionSelected(string sessionId)

    readonly property var current: sessions.find(s => s.id === selectedSession) || null

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 40
    visible: current !== null

    Label {
        id: label
        anchors.centerIn: parent
        text: picker.current ? picker.current.name + (picker.sessions.length > 1 ? "  ⌄" : "") : ""
        color: Tokens.inkSoft
    }
    MouseArea {
        anchors.fill: parent
        enabled: picker.sessions.length > 1
        onClicked: {
            const i = picker.sessions.findIndex(s => s.id === picker.selectedSession)
            picker.sessionSelected(picker.sessions[(i + 1) % picker.sessions.length].id)
        }
    }
}
