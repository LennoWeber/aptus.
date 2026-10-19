import QtQuick
import qs.theme

// Opaque base surface used by dropdowns, tiles, panels.
Rectangle {
    id: surface

    property bool elevated  // very soft shadow underneath
    property int cornerRadius: Tokens.radiusDropdown
    property bool showHairline: true

    color: Tokens.surface
    radius: cornerRadius
    border.width: showHairline ? 1 : 0
    border.color: Tokens.line

    // A soft shadow built from two faint offset layers, no glow and no effect shader.
    Rectangle {
        visible: surface.elevated
        z: -1
        anchors.fill: parent
        anchors.topMargin: 6
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        anchors.bottomMargin: -6
        radius: surface.radius
        color: Tokens.ink
        opacity: 0.05
    }
    Rectangle {
        visible: surface.elevated
        z: -1
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        radius: surface.radius
        color: Tokens.ink
        opacity: 0.04
    }
}
