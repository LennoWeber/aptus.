import QtQuick
import qs.models
import qs.theme
import qs.components

// The Wi-Fi section of the hover card: the nearby networks, a tap connects, a secured network that is not saved asks for
// its password in a row under it. Scanning runs only while the section is shown.
FocusScope {
    id: wifi

    property var networkState
    property bool shown                 // true while the section is open: scanning only then
    property string passwordFor         // the network whose password is being typed
    property int maxRows: 5
    property color ink
    property color inkSoft
    property color line
    property color fill

    signal closeRequested()

    // A tap on a network: connect or disconnect, ask for the password, or connect to a saved one.
    function tapNetwork(ssid: string, secured: bool, known: bool, connected: bool): void {
        throw new Error("not implemented")
    }

    // Connect to a network with the typed password (an empty one for an open or saved network).
    function connectTo(ssid: string, password: string): void {
        throw new Error("not implemented")
    }
}
