// Tile: Toggle tile (03 §9): 88 × 64, glyph, label, state line, chevron area for its page.
import QtQuick
import qs.core

Item {
    id: root

    property string glyph: ""
    property string label: ""
    property string stateText: ""
    property bool on: false
    property bool hasPage: false
    property string disabledReason: ""
    property bool keyboardFocus: false
    signal toggled()
    signal pageRequested()

    // Disabled with a reason: faint, no wash, the tooltip says why (03 §8); the page still opens.
    readonly property bool _disabled: disabledReason !== ""
    readonly property real _chevron: hasPage ? Tokens.tile.chevronWidth : 0
    readonly property bool _overMain: mouse.containsMouse && mouse.mouseX < width - _chevron
    readonly property bool _overChevron: mouse.containsMouse && !_overMain
    // State line swap (M-18, 04 §3 rule 5 style): the old line rises and fades, the new one rises in.
    property string _oldState: ""
    property string _lastState: ""
    property real _swap: 1

    implicitWidth: Tokens.tile.width
    implicitHeight: Tokens.tile.height
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.description: _disabled ? disabledReason : stateText
    Accessible.checkable: true
    Accessible.checked: on
    Accessible.onPressAction: if (!root._disabled) root.toggled()

    Keys.onPressed: event => {
        if ((event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !_disabled) {
            root.toggled();
            event.accepted = true;
        }
    }
    onStateTextChanged: {
        _oldState = _lastState;
        _lastState = stateText;
        if (!Motion.reduced) swapAnim.restart();
    }
    Component.onCompleted: _lastState = stateText

    StandardAnimation {
        id: swapAnim
        target: root
        property: "_swap"
        from: 0
        to: 1
        duration: Motion.ms("small", false)
    }

    Item {
        anchors.fill: parent
        scale: mouse.pressed && root._overMain && !root._disabled ? Tokens.button.pressScale : 1

        Behavior on scale {
            StandardAnimation { duration: Motion.ms("press", !mouse.pressed) }
        }

        Rectangle {
            anchors.fill: parent
            radius: Tokens.tile.radius
            color: root.on && !root._disabled
                ? (root._overMain ? ComponentShared.layer(Tokens.accentWash, Tokens.inkMain, "hover") : Tokens.accentWash)
                : (root._overMain && !root._disabled ? Tokens.raisedHot : Tokens.raised)

            Behavior on color {
                StandardColorAnimation { duration: Motion.ms("small", !root.on) }
            }
        }
        // The chevron area (right 24 px): its own hover wash, concentric with the tile's corners.
        Rectangle {
            visible: root.hasPage
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root._chevron
            topRightRadius: Tokens.tile.radius
            bottomRightRadius: Tokens.tile.radius
            color: root._overChevron ? (mouse.pressed ? Tokens.washPressed : Tokens.raisedHot) : Tokens.alpha(Tokens.raisedHot, 0)

            Behavior on color {
                StandardColorAnimation { duration: Motion.ms("hover", false) }
            }
            Glyph {
                anchors.centerIn: parent
                name: "chevron_right"
                size: Tokens.glyphRow
                colour: Tokens.inkMeta
            }
        }
        // 64 px cannot hold 12 + glyph 18 + label 19 + state 14 + 12: vertical padding s4 (spec note).
        Glyph {
            x: Tokens.padTile
            y: Tokens.s4
            name: root.glyph
            size: Tokens.glyphRow
            on: root.on
            colour: root._disabled ? Tokens.inkFaint : root.on ? Tokens.accent : Tokens.inkMain
        }
        Label {
            id: title
            x: Tokens.padTile
            anchors.bottom: stateBox.top
            width: root.width - Tokens.padTile - Math.max(Tokens.s4, root._chevron)
            text: root.label
            type: "bodyStrong"
            ink: root._disabled ? "faint" : "main"
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 1
        }
        Item {
            id: stateBox
            x: Tokens.padTile
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.s4
            width: title.width
            height: swapText.implicitHeight

            Label {
                visible: root._swap < 1
                width: parent.width
                y: -Motion.digitRoll * root._swap
                opacity: 1 - root._swap
                text: root._oldState
                type: "micro"
                ink: "meta"
                lineHeightMode: Text.ProportionalHeight
                lineHeight: 1
            }
            Label {
                id: swapText
                width: parent.width
                y: Motion.digitRoll * (1 - root._swap)
                opacity: root._swap
                text: root.stateText
                type: "micro"
                ink: root._disabled ? "faint" : "meta"
                lineHeightMode: Text.ProportionalHeight
                lineHeight: 1
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            // deck.md §3: the chevron or a right click opens the page
            if (root.hasPage && (event.button === Qt.RightButton || !root._overMain)) root.pageRequested();
            else if (event.button === Qt.LeftButton && !root._disabled) root.toggled();
        }
    }
    FocusRing {
        target: root
        targetRadius: Tokens.tile.radius
        shown: root.keyboardFocus
    }
    Tooltip {
        target: root
        text: root.disabledReason
        active: mouse.containsMouse && root._disabled
    }
}
