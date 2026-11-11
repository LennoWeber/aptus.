pragma Singleton
pragma ComponentBehavior: Bound
// Every visual token of 03-visual-language, resolved for the current mode, accent, contrast and
// glass (08-theming §3). The single source is theme/tokens.json; no component types a literal.
// Colour properties crossfade together over the theme duration (M-30, `_themeMs`).
import QtQuick
import Quickshell
import Quickshell.Io
import "js/resolve.js" as Resolve
import "js/sun.js" as Sun

Singleton {
    id: root

    // A render outside the shell (aptus-theme apply from a terminal) shows here: theme/resolved.json
    // is a stable file replaced by rename after each render (a swapped `current` symlink is not
    // noticed, phase-5 probe). Only changes count, not the first load, and none while the shell's
    // own render is pending (set by the Theme service): the file then holds an older request.
    // Equal resolutions are a no-op, so the shell's own renders do not crossfade twice (07 §7).
    property bool ownRenderBusy: false
    // True while such an outside resolution is being applied: the changes it causes are not the
    // shell's own, so the Theme service asks for no apply of them (the apps carry that render).
    property bool applyingExternal: false
    property bool _resolvedSeen: false
    function _external(text: string): void {
        const first = !_resolvedSeen;
        _resolvedSeen = true;
        if (first || ownRenderBusy) return;
        let r = null;
        try { r = JSON.parse(text); } catch (e) { Log.warn("tokens", "resolved.json: " + e); return; }
        if (_r && _canon(_r) === _canon(r)) return;
        applyingExternal = true;
        try { apply(r); } finally { applyingExternal = false; }
    }
    // JSON with sorted keys: Python and resolve.js may order keys differently.
    function _canon(v: var): string {
        if (Array.isArray(v)) return "[" + v.map(x => _canon(x)).join(",") + "]";
        if (v !== null && typeof v === "object")
            return "{" + Object.keys(v).sort().map(k => JSON.stringify(k) + ":" + _canon(v[k])).join(",") + "}";
        return JSON.stringify(v);
    }
    FileView {
        path: Paths.state + "/theme/resolved.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._external(text())
        onLoadFailed: root._resolvedSeen = true
    }

    // The parsed theme/tokens.json.
    property var raw: ({})

    // Inputs from services, wired in by shell.qml (core never imports services):
    // the wallpaper's chroma-weighted hue (−1 unknown) and mean lightness for accent "wallpaper"
    // and the glass rule.
    property real wallpaperHue: -1
    property real wallpaperLightness: -1
    property real wallpaperChroma: -1

    // Resolution result.
    readonly property string mode: _r ? _r.mode : "dark"          // "dark" | "light"
    readonly property string palette: _r ? _r.palette : "ember"      // "ember" | "linen"
    readonly property string accentName: _r ? _r.accentName : "jade"    // one of the six (also when the setting is "wallpaper")
    readonly property bool glass: _r ? _r.glass : false
    readonly property real groundAlpha: _r ? _r.groundAlpha : 1
    readonly property bool highContrast: _r ? _r.highContrast : false

    // Colour roles (animated).
    readonly property color ground: _blend("ground")
    readonly property color raised: _blend("raised")
    readonly property color raisedHot: _blend("raisedHot")
    readonly property color sunken: _blend("sunken")
    readonly property color line: _blend("line")
    readonly property color inkMain: _blend("inkMain")
    readonly property color inkSec: _blend("inkSec")
    readonly property color inkMeta: _blend("inkMeta")
    readonly property color inkFaint: _blend("inkFaint")
    readonly property color warn: _blend("warn")
    readonly property color crit: _blend("crit")
    readonly property color onAccent: _blend("onAccent")
    readonly property color accent: _blend("accent")
    readonly property color accentWash: _blend("accentWash")
    readonly property color washHover: _blend("washHover")
    readonly property color washCurrent: _blend("washCurrent")
    readonly property color washCurrentHover: _blend("washCurrentHover")
    readonly property color washPressed: _blend("washPressed")
    readonly property color selectionBg: _blend("selectionBg")
    readonly property color selectionFg: _blend("selectionFg")
    readonly property color scrim: _blend("scrim")
    readonly property color shadow: _blend("shadow")
    readonly property color frameLine: _blend("frameLine")
    // Glyph GRAD axis for the mode (0 Ember, −25 Linen); switches at the crossfade midpoint.
    property int glyphGrad: 0

    // Type.
    readonly property string fontUi: raw.type ? raw.type.families.ui : "Inter"
    readonly property string fontDisplay: raw.type ? raw.type.families.display : "Inter Display"
    readonly property string fontMono: raw.type ? raw.type.families.mono : "JetBrains Mono"
    readonly property string fontGlyph: raw.type ? raw.type.families.glyph : "Material Symbols Rounded"
    readonly property real displayFrom: raw.type ? raw.type.displayFrom : 20
    readonly property real textScale: Config.loaded ? Number(Config.get("appearance.textScale")) : 1
    // name → { size, weight, line, tracking, tabular }, already multiplied by textScale.
    readonly property var type: {
        const out = {};
        const sc = raw.type ? raw.type.scale : {};
        for (const k in sc) {
            const t = sc[k];
            out[k] = { size: t.size * textScale, weight: t.weight, line: Math.round(t.line * textScale),
                       tracking: t.tracking, tabular: !!t.tabular };
        }
        return out;
    }

    // Geometry (03 §6).
    readonly property int frameEdge: Config.loaded ? Config.get("frame.edge") : 6
    readonly property int barHeight: Config.loaded ? Config.get("bar.height") : 32
    readonly property int windowRadius: raw.geometry ? raw.geometry.windowRadius : 10
    readonly property int windowGap: raw.geometry ? raw.geometry.windowGap : 8
    readonly property int frameInnerRadius: raw.geometry ? raw.geometry.frameInnerRadius : 18
    readonly property int cove: raw.geometry ? raw.geometry.cove : 14
    readonly property int surfaceRadius: raw.geometry ? raw.geometry.surfaceRadius : 18
    readonly property int cardRadius: raw.geometry ? raw.geometry.cardRadius : 12
    readonly property int rowRadius: raw.geometry ? raw.geometry.rowRadius : 8
    readonly property int keycapRadius: raw.geometry ? raw.geometry.keycapRadius : 4
    readonly property int hitMin: raw.geometry ? raw.geometry.hitMin : 28
    readonly property int focusRingWidth: raw.geometry ? raw.geometry.focusRing.width : 2
    readonly property int focusRingGap: raw.geometry ? raw.geometry.focusRing.gap : 2
    readonly property int dragThreshold: raw.geometry ? raw.geometry.dragThreshold : 6
    readonly property real frameLineWidth: raw.frameLine ? raw.frameLine.width : 1
    readonly property real shadowOffsetY: raw.shadow ? raw.shadow.offsetY : 6
    readonly property real shadowBlur: raw.shadow ? raw.shadow.blur : 28

    // Spacing (03 §7).
    readonly property int s1: raw.spacing ? raw.spacing.s1 : 2
    readonly property int s2: raw.spacing ? raw.spacing.s2 : 4
    readonly property int s3: raw.spacing ? raw.spacing.s3 : 6
    readonly property int s4: raw.spacing ? raw.spacing.s4 : 8
    readonly property int s5: raw.spacing ? raw.spacing.s5 : 12
    readonly property int s6: raw.spacing ? raw.spacing.s6 : 16
    readonly property int s7: raw.spacing ? raw.spacing.s7 : 20
    readonly property int s8: raw.spacing ? raw.spacing.s8 : 24
    readonly property int s9: raw.spacing ? raw.spacing.s9 : 32
    readonly property int s10: raw.spacing ? raw.spacing.s10 : 48

    // Padding and gaps by context (03 §7).
    readonly property int padBar: raw.padding ? raw.padding.bar : 8            // from the frame edge: content starts 14 px from the screen edge
    readonly property int gapBarItem: raw.padding ? raw.padding.barItemGap : 8
    readonly property int gapBarZone: raw.padding ? raw.padding.barZoneGap : 16
    readonly property int padDrawer: raw.padding ? raw.padding.drawer : 16
    readonly property int gapDrawerSection: raw.padding ? raw.padding.drawerSectionGap : 12
    readonly property int gapDrawerItem: raw.padding ? raw.padding.drawerItemGap : 8
    readonly property int padRowH: raw.padding ? raw.padding.rowH : 8
    readonly property int gapRowIcon: raw.padding ? raw.padding.rowIconGap : 12
    readonly property int padTile: raw.padding ? raw.padding.tile : 12
    readonly property int padToast: raw.padding ? raw.padding.toast : 12
    readonly property int gapToastIcon: raw.padding ? raw.padding.toastIconGap : 12

    // Glyph and app-icon sizes (03 §5).
    readonly property int glyphBar: raw.glyph ? raw.glyph.sizes.bar : 16
    readonly property int glyphRow: raw.glyph ? raw.glyph.sizes.row : 18
    readonly property int glyphHeader: raw.glyph ? raw.glyph.sizes.header : 20
    readonly property int glyphToast: raw.glyph ? raw.glyph.sizes.toast : 24
    readonly property int glyphEmpty: raw.glyph ? raw.glyph.sizes.empty : 40
    readonly property int glyphWeightRest: raw.glyph ? raw.glyph.weight.rest : 400
    readonly property int glyphWeightActive: raw.glyph ? raw.glyph.weight.active : 500
    readonly property int appIconBar: raw.appIcon ? raw.appIcon.bar : 16
    readonly property int appIconPill: raw.appIcon ? raw.appIcon.pill : 14
    readonly property int appIconRow: raw.appIcon ? raw.appIcon.row : 20
    readonly property int appIconSpotlight: raw.appIcon ? raw.appIcon.spotlight : 28
    readonly property int appIconSwitcher: raw.appIcon ? raw.appIcon.switcher : 32
    readonly property int appIconToast: raw.appIcon ? raw.appIcon.toast : 24
    readonly property int appIconOverview: raw.appIcon ? raw.appIcon.overview : 48

    // Component dimensions (03 §9), as the objects of tokens.json "components".
    readonly property var button: raw.components ? raw.components.button : ({})
    readonly property var iconButton: raw.components ? raw.components.iconButton : ({})
    readonly property var tile: raw.components ? raw.components.tile : ({})
    readonly property var switchToken: raw.components ? raw.components["switch"] : ({})
    readonly property var slider: raw.components ? raw.components.slider : ({})
    readonly property var segmented: raw.components ? raw.components.segmented : ({})
    readonly property var listRow: raw.components ? raw.components.listRow : ({})
    readonly property var field: raw.components ? raw.components.field : ({})
    readonly property var keycap: raw.components ? raw.components.keycap : ({})
    readonly property var ring: raw.components ? raw.components.ring : ({})
    readonly property var level: raw.components ? raw.components.level : ({})
    readonly property var menu: raw.components ? raw.components.menu : ({})
    readonly property var tooltip: raw.components ? raw.components.tooltip : ({})
    readonly property var badge: raw.components ? raw.components.badge : ({})
    readonly property var emptyState: raw.components ? raw.components.emptyState : ({})
    readonly property var checkbox: raw.components ? raw.components.checkbox : ({})
    readonly property var rollingDigits: raw.components ? raw.components.rollingDigits : ({})
    readonly property var ellipsis: raw.components ? raw.components.ellipsis : ({})
    readonly property var pagerDots: raw.components ? raw.components.pagerDots : ({})
    readonly property var swatch: raw.components ? raw.components.swatch : ({})

    // Every accent in the current mode, in accentOrder: [{ name, label, colour }] (accent swatches),
    // and the two neutrals (ink.sec, ink.meta) for calendar colours (settings.md §5).
    readonly property var accents: (raw.accentOrder || []).map(n => ({ name: n, label: n.charAt(0).toUpperCase() + n.slice(1),
                                                                       colour: raw.accents[n][palette] }))
    readonly property var neutrals: [{ name: "ink.sec", label: "Grey", colour: inkSec }, { name: "ink.meta", label: "Stone", colour: inkMeta }]

    // Surface-specific numbers: tokens.json "surfaces" (surface → name → value).
    readonly property var surfaces: raw.surfaces || ({})

    // Resolve the palette (08 §3, core/js/resolve.js) from tokens, settings and the wallpaper,
    // and apply it (the colour properties crossfade over `_themeMs`, M-30).
    function resolveNow(): void {
        if (!raw.palettes || !Config.loaded) return;
        const m = Config.get("appearance.mode");
        apply(Resolve.resolve(raw, {
            mode: m === "auto" ? _autoMode : m,
            accent: Config.get("appearance.accent"),
            contrast: Config.get("appearance.contrast"),
            glass: Config.get("appearance.glass"),
            wallpaperHue: wallpaperHue, wallpaperChroma: wallpaperChroma, wallpaperLightness: wallpaperLightness,
            currentAccent: accentName
        }));
    }
    // Apply a resolution object (resolve.js result, or current/shell.json written outside).
    function apply(resolved: var): void {
        if (!resolved || !resolved.roles) return;
        // an unchanged resolution (a setting that does not touch the palette) starts no crossfade
        if (_r && JSON.stringify(_r) === JSON.stringify(resolved)) return;
        const gradChanges = !_r || _r.glyphGrad !== resolved.glyphGrad;
        const first = _r === null;
        // M-30: every colour crossfades from what is shown now to the new resolution
        _from = first ? _colours(resolved) : _shown();
        _r = resolved;
        _to = _colours(resolved);
        crossfade.stop();
        _t = first ? 1 : 0;
        if (!first) crossfade.start();
        // the glyph GRAD axis flips at the crossfade's midpoint (M-30)
        if (gradChanges) gradTimer.restart();
    }
    // A colour with alpha (wash layers, scrim, shadow).
    function alpha(c: color, a: real): color { return Qt.alpha(c, a); }
    // { family, pixelSize, weight, letterSpacing, lineHeight } of a type role ("body", "title", …)
    // after text scale.
    function font(role: string): var {
        const t = type[role] || type.body || { size: 13, weight: 400, line: 19, tracking: 0 };
        return { family: t.size >= displayFrom ? fontDisplay : fontUi, pixelSize: t.size, weight: t.weight,
                 letterSpacing: t.tracking * t.size, lineHeight: t.line };
    }

    // The current resolution (resolve.js result); every derived property reads it.
    property var _r: null
    // The mode `auto` resolves to now (Linen from sunrise to sunset, 08 §3 step 1).
    property string _autoMode: "dark"
    // The crossfade duration (M-30), read from raw directly: Motion reads Tokens.raw, so Tokens
    // cannot use Motion (singleton cycle).
    readonly property int _themeMs: raw.motion ? raw.motion.durations.ambient.theme : 400
    // The crossfade (M-30): role → color before and after, and the progress between them. One
    // NumberAnimation instead of a Behavior per colour: Behavior.animation is a deferred property,
    // and deferred properties crash a lazily created singleton (probe finding).
    property var _from: ({})
    property var _to: ({})
    property real _t: 1

    // role → color of a resolution.
    function _colours(r: var): var {
        const out = {};
        for (const k in r.roles) if (typeof r.roles[k] === "string") out[k] = Qt.color(r.roles[k]);
        out.scrim = Qt.alpha(r.roles.scrim, r.roles.scrimAlpha);
        out.shadow = Qt.alpha(r.roles.shadow, r.roles.shadowAlpha);
        out.frameLine = Qt.alpha(r.roles.frameLine, r.roles.frameLineAlpha);
        return out;
    }
    // role → color as shown right now (mid-crossfade included), the start of the next fade.
    function _shown(): var {
        const out = {};
        for (const k in _to) out[k] = _mix(_from[k] || _to[k], _to[k], _t);
        return out;
    }
    // Linear RGB mix of two colours (crossfade frames; cheap enough for 23 roles at 60 fps).
    function _mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }
    // A role's colour at the crossfade progress _t (each readonly role binds to it).
    function _blend(role: string): color {
        const b = _to[role];
        if (b === undefined) return "transparent";
        return _t >= 1 ? b : _mix(_from[role] || b, b, _t);
    }

    NumberAnimation {
        id: crossfade
        target: root
        property: "_t"
        from: 0
        to: 1
        duration: root._themeMs
        easing.type: Easing.InOutQuad
    }

    // Mode auto: set _autoMode from sun.js and arm the timer for the next sunrise/sunset.
    function _updateAuto(): void {
        const now = new Date();
        const loc = Config.loaded ? Config.get("weather.location") : null;
        _autoMode = Sun.modeAt(now, loc);
        autoTimer.interval = Math.max(1000, Math.min(Sun.nextChange(now, loc).getTime() - now.getTime() + 500, 2147483000));
        autoTimer.restart();
    }

    FileView {
        path: Paths.tokensFile
        blockLoading: true
        onLoaded: {
            try { root.raw = JSON.parse(text()); } catch (e) { Log.error("tokens", "tokens.json: " + e); }
        }
        onLoadFailed: error => Log.error("tokens", "tokens.json: " + FileViewError.toString(error))
    }
    Timer {
        id: autoTimer
        onTriggered: root._updateAuto()
    }
    Timer {
        id: gradTimer
        interval: root.raw.motion ? root.raw.motion.choreography.themeMidpoint : 200
        onTriggered: root.glyphGrad = root._r ? root._r.glyphGrad : 0
    }
    Connections {
        target: Config
        function onLoadedChanged(): void { root._updateAuto(); root.resolveNow(); }
        function onSettingChanged(key: string): void {
            if (key === "weather.location") root._updateAuto();
            if (key.indexOf("appearance.") === 0 || key === "weather.location") Qt.callLater(root.resolveNow);
        }
    }
    // Inputs that arrive together (a wallpaper analysis sets hue, chroma and lightness) resolve
    // once, after the current turn; the start (onCompleted, Config loaded) resolves at once.
    onRawChanged: Qt.callLater(resolveNow)
    on_AutoModeChanged: Qt.callLater(resolveNow)
    onWallpaperHueChanged: Qt.callLater(resolveNow)
    onWallpaperLightnessChanged: Qt.callLater(resolveNow)
    onWallpaperChromaChanged: Qt.callLater(resolveNow)
    Component.onCompleted: { _updateAuto(); resolveNow(); }
}
