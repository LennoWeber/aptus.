import QtQuick

// One notification received by the built-in notification server.
QtObject {
    property int id
    property string appName
    property string summary
    property string body
    property string iconName
    property int severity        // Enums.Severity
    property var timestamp       // Date
    property var actions         // list of { id, label }
    property bool read

    function dismiss(): void {
        throw new Error("not implemented")
    }

    function invokeAction(actionId: string): void {
        throw new Error("not implemented")
    }

    function markRead(): void {
        throw new Error("not implemented")
    }
}
