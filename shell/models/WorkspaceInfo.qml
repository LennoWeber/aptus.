import QtQuick

// One workspace as shown in the bar.
QtObject {
    property int id
    property string name
    property bool active
    property bool occupied
    property bool urgent

    function activate(): void {
        // TODO(phase 7): Compositor.focusWorkspace(id).
        throw new Error("not implemented")
    }
}
