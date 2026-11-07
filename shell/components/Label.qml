// Label: Text in one of the type tokens (03 §4) and one of the inks.
import QtQuick
import qs.core

Text {
    id: root

    // TODO(phase): Text with Tokens.font(role), ink colour by tone, elide right; display family from displayFrom.

    // "micro" | "bar" | "clock" | "body" | "bodyStrong" | "title" | "field" | "heading" | "number" | "display"
    property string type: "body"
    // "main" | "sec" | "meta" | "faint" | "accent" | "warn" | "crit" | "onAccent"
    property string ink: "main"
    // Tabular figures (also forced by the clock, number and display tokens).
    property bool tabular: false

    // Private state.
    // Tokens.font(type): family (display from Tokens.displayFrom), size, weight, tracking, line.
    readonly property var _font: ({})
    readonly property bool _tabular: false
}
