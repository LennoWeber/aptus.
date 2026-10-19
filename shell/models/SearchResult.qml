import QtQuick

// One entry in the launcher result list.
QtObject {
    property string id
    property int mode            // Enums.LauncherMode
    property int kind            // Enums.ResultKind
    property string title
    property string subtitle     // e.g. "Network > Wi-Fi" for settings
    property string iconName
    property string keyHint      // small shortcut hint shown on the right
    property string actionId     // identifier of the action to run on Enter
    property real score          // ranking score from the search backend
    property var run             // function that does the action; set by the search backend

    // Run the action of this result.
    function activate(): void {
        if (typeof run !== "function") throw new Error("invariant: SearchResult.activate: result has no action")
        run()
    }
}
