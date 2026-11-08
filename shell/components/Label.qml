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

    // Tokens.font(type): family (display from Tokens.displayFrom), size, weight, tracking, line.
    readonly property var _font: Tokens.font(type)
    readonly property bool _tabular: tabular || !!(Tokens.type[type] && Tokens.type[type].tabular)

    color: ComponentShared.ink(ink)
    font.family: _font.family
    font.pixelSize: _font.pixelSize
    font.weight: _font.weight
    font.letterSpacing: _font.letterSpacing
    font.features: _tabular ? { "tnum": 1 } : ({})
    lineHeightMode: Text.FixedHeight
    lineHeight: _font.lineHeight
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    textFormat: Text.PlainText
}
