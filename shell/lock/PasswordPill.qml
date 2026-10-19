import QtQuick

// Password field in the pill shape.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): same rounded form as the launcher pill; dots instead of letters; a short shake on a wrong password.

    property string placeholder
    property bool busy
    property bool error
    property int length
    signal submitted()
    signal textEdited(string text)

    function shake(): void {
        throw new Error("not implemented")
    }

    function clear(): void {
        throw new Error("not implemented")
    }
}
