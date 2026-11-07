// Base type of every interactive notch mode's content (Spotlight, Today, Switcher, …).
// The Notch hosts it, springs its bulge to bulgeWidth × bulgeHeight and routes Esc to back().
import QtQuick

Item {
    // Set by the host.
    property string monitorName: ""
    property var args: ({})
    // False while the mode is leaving (its content fades out, input stays accepted until gone).
    property bool active: true

    // The bulge size this mode wants (content plus padding). The notch animates to it.
    property real bulgeWidth: implicitWidth
    property real bulgeHeight: implicitHeight

    // Exclusive keyboard while open (false for keysPeek and hover cards).
    property bool takesKeyboard: true

    // Rows for the "?" overlay (keys-jot.md §1): [{ keys: "Esc", does: "Close" }].
    property var keys: []

    // Ask the host to close this mode (Esc at the last level, activation that leaves the shell).
    signal closeRequested()

    // Esc ladder (05 §3): step back one level inside the mode (a scope, a day view, a page).
    // Return true when it did; false lets SurfaceManager close the mode.
    function back(): bool { return false; }
}
