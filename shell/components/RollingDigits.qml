// RollingDigits: Rolling digits (03 §9, M-34): tabular figures where only changed digits roll.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): one Text per character; changed digits roll (old rises and fades, new rises from below, fade 160).

    // The text to show ("14:32", "64 %"); characters that are not digits never roll.
    property string text: ""
    // Type role of 03 §4 ("clock", "micro", "number", …).
    property string role: "body"
    property color colour

    // Private state.
    readonly property color _colour: "transparent"
    readonly property real _rise: 0
    // Rolls start after the first text is in place.
    property bool _ready: false

    // Private helpers.
    // One model row per character, right-aligned: growth inserts and shrinking removes at the front.
    function _sync(): void { throw new Error("RollingDigits._sync: not implemented"); }
}
