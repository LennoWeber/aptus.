// Button: Buttons (03 §9): primary (one per surface), plain, quiet, risk.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): label + optional glyph, kinds plain/primary/risk, press scale Tokens.button.pressScale
    //   from pressScaleMin px (03 §8), Wash, FocusRing.

    property string text: ""
    // "primary" | "plain" | "quiet" | "risk"
    property string variant: "plain"
    property string glyph: ""
    property string tooltip: ""
    // Disabled with a reason: faint, no wash, but hover stays so the tooltip says why (03 §8);
    // use this instead of `enabled: false`, which also turns off hover.
    property string disabledReason: ""
    // Show the focus ring (set by the surface after keyboard navigation).
    property bool keyboardFocus: false
    signal clicked()

    // Private state.
    readonly property bool _primary: false
    readonly property bool _quiet: false
    readonly property bool _risk: false
    // risk buttons lead with the warning glyph (03 §2.5: colour is never the only signal)
    readonly property string _glyph: ""
    readonly property string _ink: ""
    readonly property color _fill: "transparent"
}
