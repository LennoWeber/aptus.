pragma Singleton
// State shared by every component instance: the bundled glyph font (loaded once, 03 §5), the
// tooltip regrace clock (03 §9: 0 ms delay within 1 s of another tooltip) and the ink and
// state-layer lookups the components use.
import QtQuick
import qs.core

QtObject {
    id: root

    // The family name of the loaded Material Symbols Rounded (Tokens.fontGlyph until loaded).
    readonly property string glyphFamily: _glyphFont.status === FontLoader.Ready ? _glyphFont.name : Tokens.fontGlyph
    // Tooltips currently visible and when the last one hid (ms since epoch).
    property int tooltipsVisible: 0
    property real tooltipHiddenAt: 0
    // The windows that show a menu now (MenuHost marks them): a tooltip there stays hidden.
    property var menuWindows: []
    function markMenu(window: var, open: bool): void {
        const has = menuWindows.indexOf(window) >= 0;
        if (open && !has) menuWindows = menuWindows.concat([window]);
        else if (!open && has) menuWindows = menuWindows.filter(w => w !== window);
    }

    // The colour of an ink name: "main" | "sec" | "meta" | "faint" | "accent" | "warn" | "crit" | "onAccent".
    function ink(name: string): color {
        switch (name) {
        case "sec": return Tokens.inkSec;
        case "meta": return Tokens.inkMeta;
        case "faint": return Tokens.inkFaint;
        case "accent": return Tokens.accent;
        case "warn": return Tokens.warn;
        case "crit": return Tokens.crit;
        case "onAccent": return Tokens.onAccent;
        default: return Tokens.inkMain;
        }
    }
    // A state layer over a base colour (03 §2.3): `over` at the wash amount ("hover" | "current" |
    // "currentHover" | "pressed") composited on `base`. For bases without a resolved wash token
    // (accent fills, accentWash).
    function layer(base: color, over: color, amount: string): color {
        const w = Tokens.raw.washes;
        return Qt.tint(base, Qt.alpha(over, w && w[amount] !== undefined ? w[amount] : 0));
    }
    // Whether a tooltip may show without its delay (another is visible or hid within the regrace).
    function tooltipWarm(): bool {
        return tooltipsVisible > 0 || Date.now() - tooltipHiddenAt < (Tokens.tooltip.regrace || 0);
    }

    // The FontLoader (a QtObject has no default property, so it sits in a property).
    property FontLoader _glyphFont: FontLoader {
        source: Paths.url(Paths.fonts + "/MaterialSymbolsRounded.ttf")
    }
}
