import QtQuick

// One message in the AI chat mode of the launcher.
QtObject {
    property string id
    property bool fromUser
    property string text
    property bool streaming      // assistant message still arriving
    property var timestamp       // Date
}
