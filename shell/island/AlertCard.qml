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

    // Name of the app in capitals for the header line ("SPOTIFY"), "" when the alert has none.
    function appLabel(): string {
        throw new Error("not implemented")
    }

    // First letter for the badge when there is neither a cover nor an app icon.
    function badgeLetter(): string {
        throw new Error("not implemented")
    }

    signal dismissed()
    signal activated()
    signal actionInvoked(string actionId)
}
