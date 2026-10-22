import QtQuick
import qs.theme

// Three thin bars that move while music plays and rest as a short line when it does not.
Item {
    id: bars

    property bool running
    property color color: Tokens.ink
    property int barCount: 3
}
