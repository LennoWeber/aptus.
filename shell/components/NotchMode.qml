// Base type of every interactive notch mode's content (Spotlight, Today, Switcher, …).
// The Notch hosts it, springs its bulge to bulgeWidth × bulgeHeight and routes Esc to back().
// Every mode inherits the host contract (monitorName, args, takesKeyboard, keys, closeRequested,
// back) and the content choreography (04 §3 rule 1, driven by `active`) of Choreographed.
import QtQuick

Choreographed {
    shown: active

    // Set by the host, like monitorName and args: false while the mode is leaving (its content
    // fades out, input stays accepted until gone).
    property bool active: true

    // The bulge size this mode wants (content plus padding). The notch animates to it.
    property real bulgeWidth: implicitWidth
    property real bulgeHeight: implicitHeight

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
}
