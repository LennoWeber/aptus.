// A toast (surfaces/notch.md §6): app icon 24, app · time, close on hover, title, body ≤ 2 lines,
// image 48, up to three quiet action buttons, the inline reply field; the stack toast and the held
// summary are toasts too. Entrance M-06: icon 0.6 → 1, title then body rise 6 px, 40 ms apart.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The Hyprland monitor name.
    property string monitorName: ""
    // The toast payload (notifications.js).
    property var payload: ({})
    // Play the M-06 entrance (false for an in-place update: content crossfade only).
    property bool entrance: true

    // The bulge size: 420 × 72 / 104 / 132 (notch.md §6), more while the reply field is open.
    readonly property real bulgeWidth: 0
    readonly property real bulgeHeight: 0
    readonly property bool hovered: false
    // The inline reply field is open (takes the keyboard; the countdown stops).
    property bool replying: false

    // The body or a button was clicked: the action id ("" = the default action).
    signal activated(string action)
    // ✕ or middle click.
    signal dismissed()
    signal replied(string text)
    // A right click at a point in this item's coordinates.
    signal rightClicked(real x, real y)

    // M-06 entrance progress of the icon, title and body (0 → 1).
    property real _icon: 1
    property real _title: 1
    property real _body: 1

    // Open the inline reply field (the reply action) and give it the keyboard.
    function openReply(): void { throw new Error("not implemented"); }
    // Close the reply field (Esc returns to the toast; back() of the Esc ladder).
    function closeReply(): bool { throw new Error("not implemented"); }
}
