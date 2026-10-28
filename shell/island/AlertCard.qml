import QtQuick
import QtQuick.Effects
import Quickshell
import qs.models
import qs.theme
import qs.components

// The alert in the grown island: a badge or cover with the app's symbol, the app and the time, a title, a line of
// detail (artist and album, sender, text), a progress bar, action buttons and a dismiss button.
Item {
    id: card

    property var alert                   // see IslandState.alert
    property var mediaState              // MediaState, for the buttons of a music alert
    property color ink
    property color inkSoft
    property color line
    property real outerRadius: 22       // corner radius of the island body: inner shapes take outerRadius minus their margin
    property color accent                // colour of the badge, the progress and the action buttons

    property int kind: alert ? alert.kind : Enums.AlertKind.Plain
    property bool hasImage: alert ? alert.image !== "" : false      // the alert has a cover or a picture
    property bool hasProgress: progressValue >= 0                   // the alert has a progress bar (a download, a track)
    property bool hasActions: alert ? alert.actions.length > 0 : false

    readonly property bool isMedia: kind === Enums.AlertKind.Media
    readonly property bool playing: isMedia && mediaState && mediaState.available ? mediaState.playing : alert ? alert.playing : false
    // The progress of the track follows the player; the others bring their own (-1 = none).
    readonly property real progressValue: {
        if (!alert) return -1
        if (isMedia) return mediaState && mediaState.lengthSec > 0 ? Math.max(0, Math.min(1, mediaState.positionSec / mediaState.lengthSec)) : -1
        return alert.progress
    }
    readonly property real badgeSize: isMedia ? 64 : 48
    readonly property real textX: 14 + badgeSize + 12
    readonly property real sideWidth: isMedia ? 3 * 32 + 6 : 34   // room for the media buttons or the dismiss button
    readonly property string stateText: {
        switch (kind) {
        case Enums.AlertKind.Media: return playing ? "Now playing" : "Paused"
        case Enums.AlertKind.Mail: return "New mail"
        case Enums.AlertKind.Download: return alert && alert.progress >= 1 ? "Download complete" : "Download"
        case Enums.AlertKind.Timer: return "Timer"
        case Enums.AlertKind.Battery: return "Low battery"
        default: return "Now"
        }
    }
    // Artist and album for a track, the text for the rest.
    readonly property string detailText: {
        if (!alert) return ""
        if (isMedia) return [alert.detail, alert.album].filter(t => t && t !== "").join("  ·  ")
        return alert.body !== "" ? alert.body : alert.detail
    }
    readonly property string glyphKind: {
        switch (kind) {
        case Enums.AlertKind.Media: return "volume"
        case Enums.AlertKind.Mail: return "mail"
        case Enums.AlertKind.Download: return "download"
        case Enums.AlertKind.Timer: return "timer"
        case Enums.AlertKind.Battery: return "battery"
        default: return "bell"
        }
    }

    implicitHeight: Math.max(badgeSize, column.implicitHeight) + 28

    // Name of the app in capitals for the header line ("SPOTIFY"), "" when the alert has none.
    function appLabel(): string {
        return alert && alert.appName !== "" ? alert.appName.toUpperCase() : ""
    }

    // First letter for the badge when there is neither a cover nor an app icon.
    function badgeLetter(): string {
        return alert && alert.appName !== "" ? alert.appName.charAt(0).toUpperCase() : "?"
    }

    signal dismissed()
    signal activated()
    signal actionInvoked(string actionId)
    signal hoverChanged(bool hovered)

    HoverHandler { onHoveredChanged: card.hoverChanged(hovered) }

    MouseArea {
        anchors.fill: parent
        onClicked: card.activated()
    }

    // The badge: the cover or picture when there is one (with the app's symbol small in the corner), else the app's symbol, else a glyph.
    Item {
        id: badge
        x: 14
        y: 14
        width: card.badgeSize
        height: card.badgeSize

        Rectangle {
            id: plate
            anchors.fill: parent
            radius: card.isMedia ? 12 : 14
            color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.10)
            border.width: 1
            border.color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.12)
        }

        // Rounded corners for the cover: the picture is masked by the plate's shape.
        Rectangle {
            id: coverMask
            anchors.fill: parent
            radius: plate.radius
            visible: false
            layer.enabled: true
        }
        Image {
            id: cover
            anchors.fill: parent
            source: card.alert ? card.alert.image : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(card.badgeSize * 2, card.badgeSize * 2)
            visible: status === Image.Ready
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: coverMask
            }
        }

        Image {
            id: appIcon
            readonly property bool corner: cover.status === Image.Ready
            width: corner ? 22 : card.badgeSize * 0.62
            height: width
            x: corner ? parent.width - width + 5 : (parent.width - width) / 2
            y: corner ? parent.height - height + 5 : (parent.height - height) / 2
            source: card.alert ? card.alert.appIcon : ""
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            // The same picture as the cover (a sender that sends its icon as the picture): once is enough.
            visible: status === Image.Ready && source !== "" && (!card.hasImage || source !== card.alert.image)
        }

        StatusGlyph {
            anchors.centerIn: parent
            width: 22
            height: 22
            kind: card.glyphKind
            color: card.accent
            visible: !appIcon.visible && !cover.visible
        }
    }

    Column {
        id: column
        x: card.textX
        y: 14 + (Math.max(card.badgeSize, implicitHeight) - implicitHeight) / 2
        width: card.width - card.textX - card.sideWidth - 8
        spacing: 3

        Row {
            spacing: 6
            width: parent.width
            Label {
                id: appText
                text: card.appLabel()
                visible: text !== ""
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 0.7
                color: card.inkSoft
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width * 0.5)
            }
            Label {
                text: "·"
                visible: appText.visible
                font.pixelSize: 10
                color: card.inkSoft
            }
            Label {
                text: card.stateText
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 0.4
                color: card.accent
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width - x)
            }
        }

        Label {
            width: parent.width
            text: card.alert ? card.alert.text : ""
            color: card.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        Label {
            width: parent.width
            visible: text !== ""
            text: card.detailText
            color: card.isMedia ? card.inkSoft : Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.78)
            role: Enums.TextRole.Bar
            wrapMode: card.isMedia ? Text.NoWrap : Text.Wrap
            maximumLineCount: card.isMedia ? 1 : 2
            elide: Text.ElideRight
            lineHeight: 1.1
        }

        Item {
            visible: card.hasProgress
            width: parent.width
            height: 9
            Rectangle {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: 3
                radius: 1.5
                color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.16)
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * Math.max(0, card.progressValue)
                    color: card.accent
                    Behavior on width { NumberAnimation { duration: card.isMedia ? 900 : 300; easing.type: card.isMedia ? Easing.Linear : Easing.OutCubic } }
                }
            }
        }

        Row {
            visible: card.hasActions
            spacing: 6
            topPadding: 4
            Repeater {
                model: card.alert ? card.alert.actions.slice(0, 2) : []
                delegate: Rectangle {
                    id: actionButton
                    required property var modelData
                    height: 26
                    width: Math.min(actionLabel.implicitWidth + 20, 150)
                    radius: 13
                    color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, actionArea.containsMouse ? 0.22 : 0.12)
                    Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                    Label {
                        id: actionLabel
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, actionButton.width - 12)
                        text: actionButton.modelData.label
                        color: card.ink
                        role: Enums.TextRole.Bar
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: card.actionInvoked(actionButton.modelData.id)
                    }
                }
            }
        }
    }

    // A music alert has the three player buttons.
    Row {
        visible: card.isMedia
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        IslandButton { size: 32; kind: "prev"; color: card.ink; onClicked: if (card.mediaState && card.mediaState.available) card.mediaState.previous() }
        IslandButton { size: 32; kind: card.playing ? "pause" : "play"; color: card.ink; onClicked: if (card.mediaState && card.mediaState.available) card.mediaState.playPause() }
        IslandButton { size: 32; kind: "next"; color: card.ink; onClicked: if (card.mediaState && card.mediaState.available) card.mediaState.next() }
    }

    // The others have a small dismiss button: the cross is two thin bars.
    Item {
        visible: !card.isMedia
        x: card.width - 14 - 24
        y: 12
        width: 24
        height: 24
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, dismissArea.containsMouse ? 0.18 : 0.08)
            Behavior on color { ColorAnimation { duration: Tokens.durFast } }
        }
        Repeater {
            model: [45, -45]
            delegate: Rectangle {
                required property int modelData
                anchors.centerIn: parent
                width: 10
                height: 1.5
                radius: 1
                rotation: modelData
                color: card.ink
            }
        }
        MouseArea {
            id: dismissArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: card.dismissed()
        }
    }
}
