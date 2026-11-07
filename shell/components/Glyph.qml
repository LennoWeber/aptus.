// Glyph: A Material Symbols Rounded glyph (03 §5). FILL and wght follow `on`/`active` and animate (P-17);
// a change of `name` crossfades the old glyph out and scales the new one 0.8 → 1 (04 §3 rule 6), so
// Glyph is an Item holding two Texts.
import QtQuick
import qs.core

Item {
    id: root
    // TODO(phase): the size default comes from Tokens.glyphRow, not a literal.

    // TODO(phase): Material Symbols Rounded via ComponentShared.glyphFamily (one FontLoader), two Texts
    //   with font.variableAxes FILL/wght animated over `small` (P-17 confirms on hardware in S3); opsz
    //   clamped to the font's 20..48; a name change runs the swap (_previous fades, new 0.8 → 1).

    // The symbol name (ligature), e.g. "wifi".
    property string name: ""
    property real size: 18
    // FILL 1 when on.
    property bool on: false
    // wght 500 when active.
    property bool active: false
    property color colour

    // Private state.
    // The animated axis values (04 §3 rule 6: FILL 0↔1 and wght 400↔500 over `small`).
    property real _fill
    property real _wght
    // The glyph being swapped out and the swap progress 0 → 1.
    property string _previous: ""
    property real _swap: 1
}
