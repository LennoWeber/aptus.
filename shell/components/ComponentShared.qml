pragma Singleton
// State shared by every component instance: the bundled glyph font (loaded once, 03 §5), the
// tooltip regrace clock (03 §9: 0 ms delay within 1 s of another tooltip) and the ink and
// state-layer lookups the components use.
import QtQuick
import qs.core

QtObject {
    id: root

    // TODO(phase): a FontLoader on Paths.fonts + "/MaterialSymbolsRounded.ttf" (the repo's copy; no
    //   font is installed, CLAUDE.md); glyphFamily ← its name once Ready.

    // The family name of the loaded Material Symbols Rounded (Tokens.fontGlyph until loaded).
    readonly property string glyphFamily: ""
    // Tooltips currently visible and when the last one hid (ms since epoch).
    property int tooltipsVisible: 0
    property real tooltipHiddenAt: 0

    // The colour of an ink name: "main" | "sec" | "meta" | "faint" | "accent" | "warn" | "crit" | "onAccent".
    function ink(name: string): color { throw new Error("ComponentShared.ink: not implemented"); }
    // A state layer over a base colour (03 §2.3): `over` at the wash amount ("hover" | "current" |
    // "currentHover" | "pressed") composited on `base`. For bases without a resolved wash token
    // (accent fills, accentWash).
    function layer(base: color, over: color, amount: string): color { throw new Error("ComponentShared.layer: not implemented"); }
    // Whether a tooltip may show without its delay (another is visible or hid within the regrace).
    function tooltipWarm(): bool { throw new Error("ComponentShared.tooltipWarm: not implemented"); }
}
