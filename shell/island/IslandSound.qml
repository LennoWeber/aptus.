import QtQuick
import qs.models
import qs.theme
import qs.components

// The Sound section of the hover card: the output devices, a tap makes one the output.
FocusScope {
    id: sound

    property var audioState
    property bool shown                 // true while the section is open
    property int maxRows
    property color ink
    property color inkSoft
    property color line
    property color fill

    signal closeRequested()

    // A tap on a device: it becomes the output.
    function setOutput(outputId: string): void {
        throw new Error("not implemented")
    }
}
