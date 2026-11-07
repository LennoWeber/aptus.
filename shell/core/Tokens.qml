pragma Singleton
// Every visual token of 03-visual-language, resolved for the current mode, accent, contrast and
// glass (08-theming §3). The single source is theme/tokens.json; no component types a literal.
// Colour properties animate together over Motion's theme duration (M-30).
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): FileView on Paths.tokensFile (blockLoading) → raw; every geometry/type/component
    //   property reads raw instead of its literal default.
    // TODO(phase): textScale ← Config appearance.textScale; barHeight from raw type.textScale.barHeight
    //   (32/35/40) and `type` scaled by it; frameEdge ← Config frame.edge (the reserve zone follows).
    // TODO(phase): resolveNow() on Config appearance.* changes and on wallpaperHue/Lightness changes;
    //   ColorAnimation Behaviors over Motion.theme on every colour (M-30).
    // TODO(phase): accents/neutrals from raw.accents + accentOrder for the current mode; wallpaperChroma
    //   into resolve.js (low-chroma images keep the current accent).
    // TODO(phase): watch Paths.themeCurrent + "/shell.json" for resolutions written outside (07 §7).

    // The parsed theme/tokens.json.
    property var raw: ({})

    // Inputs from services, wired in by shell.qml (core never imports services):
    // the wallpaper's chroma-weighted hue (−1 unknown) and mean lightness for accent "wallpaper"
    // and the glass rule.
    property real wallpaperHue: -1
    property real wallpaperLightness: -1
    property real wallpaperChroma: -1

    // Resolution result.
    readonly property string mode: "dark"          // "dark" | "light"
    readonly property string palette: "ember"      // "ember" | "linen"
    readonly property string accentName: "jade"    // one of the six (also when the setting is "wallpaper")
    readonly property bool glass: false
    readonly property real groundAlpha: 1
    readonly property bool highContrast: false

    // Colour roles (animated).
    property color ground
    property color raised
    property color raisedHot
    property color sunken
    property color line
    property color inkMain
    property color inkSec
    property color inkMeta
    property color inkFaint
    property color warn
    property color crit
    property color onAccent
    property color accent
    property color accentWash
    property color washHover
    property color washCurrent
    property color washCurrentHover
    property color washPressed
    property color selectionBg
    property color selectionFg
    property color scrim
    property color shadow
    property color frameLine
    // Glyph GRAD axis for the mode (0 Ember, −25 Linen); switches at the crossfade midpoint.
    property int glyphGrad: 0

    // Type.
    readonly property string fontUi: "Inter"
    readonly property string fontDisplay: "Inter Display"
    readonly property string fontMono: "JetBrains Mono"
    readonly property string fontGlyph: "Material Symbols Rounded"
    readonly property real displayFrom: 20
    readonly property real textScale: 1
    // name → { size, weight, line, tracking, tabular }, already multiplied by textScale.
    readonly property var type: ({})

    // Geometry (03 §6).
    readonly property int frameEdge: 6
    readonly property int barHeight: 32
    readonly property int windowRadius: 10
    readonly property int windowGap: 8
    readonly property int frameInnerRadius: 18
    readonly property int cove: 14
    readonly property int surfaceRadius: 18
    readonly property int cardRadius: 12
    readonly property int rowRadius: 8
    readonly property int keycapRadius: 4
    readonly property int hitMin: 28
    readonly property int focusRingWidth: 2
    readonly property int focusRingGap: 2
    readonly property int dragThreshold: 6
    readonly property real frameLineWidth: 1
    readonly property real shadowOffsetY: 6
    readonly property real shadowBlur: 28

    // Spacing (03 §7).
    readonly property int s1: 2
    readonly property int s2: 4
    readonly property int s3: 6
    readonly property int s4: 8
    readonly property int s5: 12
    readonly property int s6: 16
    readonly property int s7: 20
    readonly property int s8: 24
    readonly property int s9: 32
    readonly property int s10: 48

    // Padding and gaps by context (03 §7).
    readonly property int padBar: 8            // from the frame edge: content starts 14 px from the screen edge
    readonly property int gapBarItem: 8
    readonly property int gapBarZone: 16
    readonly property int padDrawer: 16
    readonly property int gapDrawerSection: 12
    readonly property int gapDrawerItem: 8
    readonly property int padRowH: 8
    readonly property int gapRowIcon: 12
    readonly property int padTile: 12
    readonly property int padToast: 12
    readonly property int gapToastIcon: 12

    // Glyph and app-icon sizes (03 §5).
    readonly property int glyphBar: 16
    readonly property int glyphRow: 18
    readonly property int glyphHeader: 20
    readonly property int glyphToast: 24
    readonly property int glyphEmpty: 40
    readonly property int glyphWeightRest: 400
    readonly property int glyphWeightActive: 500
    readonly property int appIconBar: 16
    readonly property int appIconPill: 14
    readonly property int appIconRow: 20
    readonly property int appIconSpotlight: 28
    readonly property int appIconSwitcher: 32
    readonly property int appIconToast: 24
    readonly property int appIconOverview: 48

    // Component dimensions (03 §9), as the objects of tokens.json "components".
    readonly property var button: ({})
    readonly property var iconButton: ({})
    readonly property var tile: ({})
    readonly property var switchToken: ({})
    readonly property var slider: ({})
    readonly property var segmented: ({})
    readonly property var listRow: ({})
    readonly property var field: ({})
    readonly property var keycap: ({})
    readonly property var ring: ({})
    readonly property var level: ({})
    readonly property var menu: ({})
    readonly property var tooltip: ({})
    readonly property var badge: ({})
    readonly property var emptyState: ({})
    readonly property var checkbox: ({})
    readonly property var rollingDigits: ({})
    readonly property var ellipsis: ({})
    readonly property var pagerDots: ({})
    readonly property var swatch: ({})

    // Every accent in the current mode, in accentOrder: [{ name, label, colour }] (accent swatches),
    // and the two neutrals (ink.sec, ink.meta) for calendar colours (settings.md §5).
    readonly property var accents: []
    readonly property var neutrals: []

    // Surface-specific numbers: tokens.json "surfaces" (surface → name → value).
    readonly property var surfaces: ({})

    // Resolve the palette (08 §3, core/js/resolve.js) from tokens, settings and the wallpaper,
    // and apply it (the colour properties animate over Motion.ambientTheme, M-30).
    function resolveNow(): void { throw new Error("Tokens.resolveNow: not implemented"); }
    // Apply a resolution object (resolve.js result, or current/shell.json written outside).
    function apply(resolved: var): void { throw new Error("Tokens.apply: not implemented"); }
    // A colour with alpha (wash layers, scrim, shadow).
    function alpha(c: color, a: real): color { throw new Error("Tokens.alpha: not implemented"); }
    // { family, pixelSize, weight, letterSpacing, lineHeight } of a type role ("body", "title", …)
    // after text scale.
    function font(role: string): var { throw new Error("Tokens.font: not implemented"); }
}
