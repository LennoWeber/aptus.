// Base type of every interactive notch mode's content (Spotlight, Today, Switcher, …).
// The Notch hosts it, springs its bulge to bulgeWidth × bulgeHeight and routes Esc to back().
// Every mode inherits the content choreography of Choreographed (04 §3 rule 1), driven by `active`.
import QtQuick

Choreographed {
    shown: active

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

    // Dim everything behind the notch (polkit, the session sheet; M-27).
    property bool scrim: false
    // Clicks outside close the mode (away catcher); false for keysPeek.
    property bool catchesOutside: takesKeyboard
    // The spring for size changes inside the mode ("gentle": M-10/M-11); the morph between modes
    // always uses spring.notch.
    property string sizeSpring: "gentle"
    // M-20: the rest clock's rectangle in this mode's coordinates (set by the host), and whether
    // the mode takes the clock over (the notch hides its own clock while the mode is open).
    property rect clockRect
    property bool takesClock: false

    // Rows for the "?" overlay (keys-jot.md §1): [{ keys: "Esc", does: "Close" }].
    property var keys: []

    // Ask the host to close this mode (Esc at the last level, activation that leaves the shell).
    signal closeRequested()

    // Esc ladder (05 §3): step back one level inside the mode (a scope, a day view).
    // Return true when it did; false lets SurfaceManager close the mode.
    function back(): bool { return false; }
}
