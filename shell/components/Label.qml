// Label: Text in one of the type tokens (03 §4) and one of the inks.
import QtQuick
import qs.core

Text {
    id: root

    // "micro" | "bar" | "clock" | "body" | "bodyStrong" | "title" | "field" | "heading" | "number" | "display"
    property string type: "body"
    // "main" | "sec" | "meta" | "faint" | "accent" | "warn" | "crit" | "onAccent"
    property string ink: "main"
    // Tabular figures (also forced by the clock, number and display tokens).
    property bool tabular: false
}
