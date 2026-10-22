import QtQuick
import qs.models
import qs.theme
import qs.components

// The notch at rest: the time in the middle, and in the two wings what is going on (cover and level bars while music
// plays, a timer, a recording, caffeine or focus). Both wings are as wide as the wider one, so the time never moves.
Item {
    id: rest

    property var mediaState
    property var timerState
    property var captureState
    property var caffeineState
    property var focusState
    property bool mediaWingsOn
    property string look: "light"
    property string clockFormat: "24h"
    property bool showSeconds

    // What the wings hold now; read by Notch to size the pill.
    property real wingWidth
    property real clockWidth
    readonly property real restWidth: 0
}
