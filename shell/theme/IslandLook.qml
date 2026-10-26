pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The look of the island (setting island.look). The ten looks are data in theme/island-looks.json; the values
// below are those of the chosen look, resolved against the current colours of Tokens.
Singleton {
    id: root

    property string lookId: "paper"
    property string name
    property var looks                    // raw data of theme/island-looks.json: { id, name, ... } per look

    // colours: Rest = pill and alert, Open = hover panel and opened island
    property color fillRest
    property color fillOpen
    property color inkRest
    property color inkSoftRest
    property color inkOpen
    property color strokeRest
    property color strokeOpen
    property real strokeWidthRest
    property real strokeWidthOpen

    // shape
    property real radiusRest
    property real radiusOpen
    property real gap                     // distance from the top edge in px, 0 = flush with the edge
    property bool monoClock               // the time in the mono font
    property bool accentLine              // 2 px signal line at the bottom edge

    FileView {
        id: looksFile
        path: Tokens.rootDir + "/theme/island-looks.json"
        blockLoading: true
        printErrors: false
    }

    readonly property string defaultId: "paper"

    // Read theme/island-looks.json.
    function load(): void {
        throw new Error("not implemented")
    }

    // Make lookId the current look and resolve its values against the colours of Tokens. An unknown id falls back to defaultId.
    function apply(lookId: string): void {
        throw new Error("not implemented")
    }

    // The look names for the settings, in file order: a list of objects with id and name.
    function names(): var {
        throw new Error("not implemented")
    }

    // Colour of Tokens by its name in the looks file (bg, surface, surfaceAlt, line, ink, wash1, wash2).
    function colorByName(colorName: string): color {
        throw new Error("not implemented")
    }
}
