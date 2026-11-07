// RollingDigits: Rolling digits (03 §9, M-34): tabular figures where only changed digits roll.
import QtQuick
import qs.core

Item {
    id: root

    // The text to show ("14:32", "64 %"); characters that are not digits never roll.
    property string text: ""
    // Type role of 03 §4 ("clock", "micro", "number", …).
    property string role: "body"
    property color colour
}
