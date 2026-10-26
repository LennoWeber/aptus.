import QtQuick
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
    property color accent                // colour of the badge, the progress and the action buttons

    property int kind                    // Enums.AlertKind of the alert
    property bool hasImage               // the alert has a cover or a picture
    property bool hasProgress            // the alert has a progress bar (a download, a track)
    property bool hasActions             // the alert has action buttons
    property bool isMedia                // a track
    property bool playing                // a track plays (live from the player, else from the alert)
    property real progressValue          // 0..1, -1 = none (a track follows the player)
    property real badgeSize              // side of the badge or cover (px)
    property real textX                  // where the text column starts
    property real sideWidth              // room on the right for the player buttons or the dismiss button
    property string stateText            // "Now playing", "New mail", "Download complete" ...
    property string detailText           // artist and album, or the text
    property string glyphKind            // StatusGlyph kind for the badge when there is no cover and no app icon

    // Name of the app in capitals for the header line ("SPOTIFY"), "" when the alert has none.
    function appLabel(): string {
        if (!alert) throw new Error("invariant: AlertCard.appLabel: no alert")
        throw new Error("not implemented")
    }

    // First letter for the badge when there is neither a cover nor an app icon.
    function badgeLetter(): string {
        if (!alert) throw new Error("invariant: AlertCard.badgeLetter: no alert")
        throw new Error("not implemented")
    }

    // TODO(phase 7, alerts): the content: badge or cover with app symbol, header, title, detail, progress, actions, dismiss, media buttons.
    signal dismissed()
    signal activated()
    signal actionInvoked(string actionId)
    signal hoverChanged(bool hovered)   // the pointer is on the card (the alert stays while it is)
}
