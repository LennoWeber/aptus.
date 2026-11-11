// Every Material Symbols name S3 uses exists as a ligature in the bundled font (a missing name
// would render as its letters): each one shapes to a single glyph of the icon's width.
import QtQuick
import QtTest
import "../../shell/services/js/levels.js" as L
import "../../shell/services/js/status.js" as S
import "../../shell/services/js/notifications.js" as N
import "../../shell/surfaces/bar/js/bar.js" as B

TestCase {
    name: "glyphs"

    // The names written into S3's QML (bar, notch, the services' events and system toasts).
    readonly property var qmlNames: ["close", "expand_more", "grid_view", "pause", "play_arrow", "repeat", "repeat_one",
        "shuffle", "skip_next", "skip_previous", "terminal", "warning", "reply", "visibility_off", "notifications_off",
        "do_not_disturb_on", "settings", "today", "center_focus_strong", "calendar_month", "music_off", "battery_alert",
        "notifications_active"]
    readonly property int px: 48

    FontLoader {
        id: symbols
        source: Qt.resolvedUrl("../../shell/assets/fonts/MaterialSymbolsRounded.ttf")
    }
    TextMetrics {
        id: metrics
        font.family: symbols.name
        font.pixelSize: 48
    }

    function values(o) { return Object.keys(o).map(k => o[k]) }
    function menuGlyphs(rows) {
        let out = []
        for (const r of rows) {
            if (r.glyph) out.push(r.glyph)
            if (r.submenu) out = out.concat(menuGlyphs(r.submenu))
        }
        return out
    }
    function names() {
        const window = { floating: true, pinned: true, fullscreen: true, workspace: 1 }
        const all = [].concat(L.BATTERY, L.WIFI, L.VOLUME, values(L.GLYPHS), values(B.WINDOW_GLYPHS),
                              values(S.EVENT_GLYPHS), [N.FALLBACK_GLYPH], qmlNames,
                              menuGlyphs(B.windowMenu(window, ["eDP-1", "DP-3"], "eDP-1")),
                              menuGlyphs(B.windowMenu({ floating: false, pinned: false, fullscreen: false, workspace: 1 }, ["eDP-1"], "eDP-1")),
                              menuGlyphs(B.pillMenu({ id: 2, windows: 1 }, ["eDP-1", "DP-3"], "eDP-1")))
        return all.filter((n, i) => all.indexOf(n) === i)
    }

    function test_every_glyph_is_a_ligature() {
        tryCompare(symbols, "status", FontLoader.Ready)
        const list = names()
        verify(list.length > 40, "only " + list.length + " names collected")
        // a word in letters is several times as wide as one icon
        metrics.text = "settings"
        const icon = metrics.advanceWidth
        verify(icon > 0 && icon <= px * 1.05, "the reference ligature is " + icon + " px wide")
        const missing = []
        for (const n of list) {
            metrics.text = n
            if (Math.abs(metrics.advanceWidth - icon) > 1) missing.push(n + " (" + metrics.advanceWidth + " px)")
        }
        compare(missing, [])
    }
}
