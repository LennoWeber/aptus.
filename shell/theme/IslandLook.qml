pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The look of the island (setting island.look). The ten looks are data in theme/island-looks.json; the values
// below are those of the chosen look, resolved against the current colours of Tokens.
Singleton {
    id: root

    property string lookId: "paper"
    property string name: entry("name") || ""
    property var looks                    // raw data of theme/island-looks.json: { id, name, ... } per look

    // colours: Rest = pill and alert, Open = hover panel and opened island
    property color fillRest: colorByName(entry("fillRest") || "")
    property color fillOpen: colorByName(entry("fillOpen") || "")
    property color inkRest: colorByName(entry("inkRest") || "")
    property color inkSoftRest: Qt.rgba(inkRest.r, inkRest.g, inkRest.b, 0.65)
    property color inkOpen: colorByName(entry("inkOpen") || "")
    property color strokeRest: colorByName(entry("strokeRest") || "")
    property color strokeOpen: colorByName(entry("strokeOpen") || "")
    property real strokeWidthRest: entry("strokeWidthRest") ?? 1
    property real strokeWidthOpen: entry("strokeWidthOpen") ?? 1

    // shape
    property real radiusRest: entry("radiusRest") ?? 14
    property real radiusOpen: entry("radiusOpen") ?? 22
    // The design (setting island.design) decides the height at rest and whether the island floats; the look the rest.
    property string design: "capsule"                        // capsule, ninja, ticker or shade
    readonly property real restHeight: design === "ninja" ? 36 : design === "shade" ? 6 : Tokens.barHeight
    readonly property real gap: design === "ninja" ? 6 : design === "capsule" ? (entry("gap") ?? 0) : 0   // distance from the top edge in px, 0 = flush with the edge
    property bool monoClock: entry("monoClock") === true     // the time in the mono font
    property bool accentLine: entry("accentLine") === true   // 2 px signal line at the bottom edge

    readonly property string defaultId: "paper"

    FileView {
        id: looksFile
        path: Tokens.rootDir + "/theme/island-looks.json"
        blockLoading: true
        printErrors: false
    }

    // The raw entry of the current look for a key, undefined while the file is not loaded.
    function entry(key: string): var {
        const list = looks || []
        const found = list.find(l => l.id === lookId) || list.find(l => l.id === defaultId)
        return found ? found[key] : undefined
    }

    // Read theme/island-looks.json.
    function load(): void {
        try {
            looks = JSON.parse(looksFile.text()).looks
        } catch (e) {
            console.error("aptus: cannot read island-looks.json (" + e + "), using the built-in paper look")
        }
    }

    // Make lookId the current look and resolve its values against the colours of Tokens. An unknown id falls back to defaultId.
    function apply(newId: string): void {
        const list = looks || []
        lookId = list.some(l => l.id === newId) ? newId : defaultId
    }

    // The look names for the settings, in file order: a list of objects with id and name.
    function names(): var {
        return (looks || []).map(l => ({ id: l.id, name: l.name }))
    }

    // Colour of Tokens by its name in the looks file (bg, surface, surfaceAlt, line, ink, wash1, wash2).
    function colorByName(colorName: string): color {
        switch (colorName) {
        case "bg": return Tokens.bg
        case "surfaceAlt": return Tokens.surfaceAlt
        case "line": return Tokens.line
        case "ink": return Tokens.ink
        case "wash1": return Tokens.wash1
        case "wash2": return Tokens.wash2
        default: return Tokens.surface
        }
    }
}
