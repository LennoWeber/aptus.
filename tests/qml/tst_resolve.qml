// Palette resolution (08 §3).
import QtQuick
import QtTest
import "../../shell/core/js/resolve.js" as Lib
import "../../shell/core/js/colour.js" as Colour

TestCase {
    name: "resolve"

    property var tokens: null

    function initTestCase() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", Qt.resolvedUrl("../../theme/tokens.json"), false)
        xhr.send()
        tokens = JSON.parse(xhr.responseText)
    }
    function inp(o) {
        var d = { mode: "dark", accent: "jade", contrast: "normal", glass: false,
                  wallpaperHue: -1, wallpaperChroma: -1, wallpaperLightness: -1, currentAccent: "jade" }
        for (var k in o) d[k] = o[k]
        return d
    }

    function test_ember_base_roles() {
        var r = Lib.resolve(tokens, inp({}))
        var p = tokens.palettes.ember
        compare(r.mode, "dark")
        compare(r.palette, "ember")
        compare(r.roles.ground, "#191613")
        compare(r.roles.ground, p.ground)
        compare(r.roles.raised, p.raised)
        compare(r.roles.raisedHot, p.raisedHot)
        compare(r.roles.sunken, p.sunken)
        compare(r.roles.line, p.line)
        compare(r.roles.inkMain, p.ink.main)
        compare(r.roles.inkSec, p.ink.sec)
        compare(r.roles.inkMeta, p.ink.meta)
        compare(r.roles.inkFaint, p.ink.faint)
        compare(r.roles.warn, p.warn)
        compare(r.roles.crit, p.crit)
        compare(r.roles.onAccent, p.onAccent)
        compare(r.roles.accent, "#9acfae")
        compare(r.roles.scrimAlpha, 0.45)
        compare(r.roles.shadowAlpha, 0.38)
        compare(r.roles.frameLineAlpha, 0.7)
        compare(r.accentName, "jade")
        compare(r.papirus, "teal")
        compare(Object.keys(r.roles).join(","), Lib.ROLES.join(","))
    }

    function test_linen_base_roles() {
        var r = Lib.resolve(tokens, inp({ mode: "light", accent: "apricot" }))
        var p = tokens.palettes.linen
        compare(r.mode, "light")
        compare(r.palette, "linen")
        compare(r.roles.ground, "#f4ede1")
        compare(r.roles.inkMain, "#272119")
        compare(r.roles.raised, p.raised)
        compare(r.roles.line, p.line)
        compare(r.roles.warn, p.warn)
        compare(r.roles.onAccent, p.onAccent)
        compare(r.roles.accent, "#9a4f1c")
        compare(r.roles.scrimAlpha, 0.28)
        compare(r.roles.shadowAlpha, 0.18)
        compare(r.glyphGrad, -25)
    }

    function test_washes() {
        var r = Lib.resolve(tokens, inp({}))
        var p = tokens.palettes.ember
        compare(r.roles.washHover, Colour.over(p.ink.main, p.ground, 0.06))
        compare(r.roles.washCurrent, Colour.over(p.ink.main, p.ground, 0.10))
        compare(r.roles.washCurrentHover, Colour.over(p.ink.main, p.ground, 0.14))
        compare(r.roles.washPressed, Colour.over(p.ink.main, p.ground, 0.18))
        compare(r.roles.accentWash, Colour.over("#9acfae", p.ground, 0.16))
        // wash strength grows monotonically in lightness for the dark palette
        function L(h) { return Colour.hexToOklab(h)[0] }
        verify(L(r.roles.washHover) < L(r.roles.washCurrent))
        verify(L(r.roles.washCurrent) < L(r.roles.washCurrentHover))
        verify(L(r.roles.washCurrentHover) < L(r.roles.washPressed))
        verify(L(r.roles.washHover) > L(p.ground))
    }

    function test_selection_amount() {
        var d = Lib.resolve(tokens, inp({}))
        compare(d.roles.selectionBg, Colour.over("#9acfae", "#191613", 0.28))
        compare(d.roles.selectionFg, "#efe6d4")
        var l = Lib.resolve(tokens, inp({ mode: "light" }))
        compare(l.roles.selectionBg, Colour.over("#25704f", "#f4ede1", 0.22))
    }

    function test_contrast_high() {
        var n = Lib.resolve(tokens, inp({}))
        var h = Lib.resolve(tokens, inp({ contrast: "high" }))
        var p = tokens.palettes.ember
        compare(h.highContrast, true)
        compare(n.highContrast, false)
        compare(h.roles.inkSec, Colour.toward(p.ink.sec, p.ink.main, 0.35))
        compare(h.roles.inkMeta, Colour.toward(p.ink.meta, p.ink.main, 0.35))
        compare(h.roles.inkMain, n.roles.inkMain)
        compare(h.roles.inkFaint, n.roles.inkFaint)
        function L(x) { return Colour.hexToOklab(x)[0] }
        verify(L(h.roles.inkMeta) > L(n.roles.inkMeta))
        verify(L(h.roles.inkMeta) <= L(p.ink.main))
        // light: moves darker
        var hl = Lib.resolve(tokens, inp({ mode: "light", contrast: "high" }))
        var nl = Lib.resolve(tokens, inp({ mode: "light" }))
        verify(L(hl.roles.inkMeta) < L(nl.roles.inkMeta))
    }

    function test_glass_alpha() {
        compare(Lib.resolve(tokens, inp({ glass: false })).groundAlpha, 1.0)
        compare(Lib.resolve(tokens, inp({ glass: true })).groundAlpha, 0.86)
        compare(Lib.resolve(tokens, inp({ glass: true, wallpaperLightness: 0.2 })).groundAlpha, 0.86)
        // dark mode with a light wallpaper: wrong half
        compare(Lib.resolve(tokens, inp({ glass: true, wallpaperLightness: 0.8 })).groundAlpha, 0.92)
        // light mode with a dark wallpaper
        compare(Lib.resolve(tokens, inp({ mode: "light", glass: true, wallpaperLightness: 0.2 })).groundAlpha, 0.92)
        compare(Lib.resolve(tokens, inp({ mode: "light", glass: true, wallpaperLightness: 0.8 })).groundAlpha, 0.86)
        compare(Lib.resolve(tokens, inp({ glass: false, wallpaperLightness: 0.9 })).groundAlpha, 1.0)
    }

    function test_wallpaper_accent_nearest() {
        function name(hue) { return Lib.resolve(tokens, inp({ accent: "wallpaper", wallpaperHue: hue, wallpaperChroma: 0.1, currentAccent: "jade" })).accentName }
        compare(name(230), "sky")
        compare(name(295), "iris")
        compare(name(355), "rose")
        compare(name(5), "rose")
        compare(name(60), "apricot")
        compare(name(90), "sand")
        compare(name(150), "jade")
        // linen palette uses its own hues
        var r = Lib.resolve(tokens, inp({ mode: "light", accent: "wallpaper", wallpaperHue: 232, wallpaperChroma: 0.1 }))
        verify(tokens.accentOrder.indexOf(r.accentName) >= 0)
        compare(r.roles.accent, tokens.accents[r.accentName].linen)
        // a fixed accent ignores the wallpaper
        compare(Lib.resolve(tokens, inp({ accent: "iris", wallpaperHue: 60, wallpaperChroma: 0.1 })).accentName, "iris")
    }

    function test_wallpaper_accent_tie_keeps_current() {
        var ha = Colour.hue(tokens.accents.apricot.ember), hs = Colour.hue(tokens.accents.sand.ember)
        var mid = (ha + hs) / 2
        function name(cur) { return Lib.accentFor(tokens, "wallpaper", mid, 0.1, cur, "ember") }
        compare(name("apricot"), "apricot")
        compare(name("sand"), "sand")
    }

    function test_wallpaper_low_chroma() {
        var r = Lib.resolve(tokens, inp({ accent: "wallpaper", wallpaperHue: 230, wallpaperChroma: 0.01, currentAccent: "rose" }))
        compare(r.accentName, "rose")
        compare(Lib.resolve(tokens, inp({ accent: "wallpaper", wallpaperHue: -1, wallpaperChroma: -1, currentAccent: "sand" })).accentName, "sand")
        // unknown current falls back to the first accent
        compare(Lib.resolve(tokens, inp({ accent: "wallpaper", wallpaperChroma: 0.0, currentAccent: "nope" })).accentName, "jade")
    }

    function test_ansi_fixed() {
        var accents = tokens.accentOrder
        for (var i = 0; i < accents.length; i++) {
            var r = Lib.resolve(tokens, inp({ accent: accents[i] }))
            compare(r.ansi.length, 16)
            compare(r.ansi.join(","), tokens.palettes.ember.ansi.join(","))
        }
        var l = Lib.resolve(tokens, inp({ mode: "light", accent: "sky" }))
        compare(l.ansi.join(","), tokens.palettes.linen.ansi.join(","))
        var h = Lib.resolve(tokens, inp({ contrast: "high" }))
        compare(h.ansi.join(","), tokens.palettes.ember.ansi.join(","))
    }
}
