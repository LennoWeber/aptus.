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
    // TODO(phase): notch.js bulgeSize("toast", payload, …).
    readonly property real bulgeWidth: 0
    readonly property real bulgeHeight: 0
    // TODO(phase): a HoverHandler over the toast.
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
    // Close the reply field (Esc in the field returns to the toast; the field has the keyboard
    // through Notch.wantsKeyboard, not the shell's Esc ladder).
    function closeReply(): bool { throw new Error("not implemented"); }

    // TODO(phase): app icon 24 (or payload.glyph), app · time (micro), ✕ on hover, title (crit
    //   warning glyph), body ≤ 2 lines (StyledText of reduced markup, links open), image 48,
    //   ≤ 3 quiet action buttons, reply Field (takes the keyboard; Enter → replied, Esc →
    //   closeReply), stack icons; click body → activated(""), middle → dismissed, right →
    //   rightClicked; entrance M-06.

    // Found by the probe (phase 5):
    // The toast's tokens, the stack record (null for a single toast) and the buttons (the
    // actions, plus Reply when the sender allows it).
    // TODO(phase): Tokens.surfaces.toast; payload.stack; payload.actions (+ { id: "__reply" }).
    readonly property var _t: ({})
    readonly property var _stack: null
    readonly property var _actions: []
    // TODO(phase): one body line while buttons show (the 104/132 heights fit one); the critical
    //   warning glyph for every critical notification (nid ≠ 0), system toasts keep their own.
}
