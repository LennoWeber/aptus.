// Settings validation (10, settings.md §4).
import QtQuick
import QtTest
import "../../shell/core/js/config.js" as Lib

TestCase {
    name: "config"

    property var schema: null
    readonly property string home: "/home/t"

    function initTestCase() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", Qt.resolvedUrl("../../shell/config/settings-schema.json"), false)
        xhr.send()
        schema = JSON.parse(xhr.responseText)
    }
    function v(key, value, exists) { return Lib.validate(schema, key, value, home, exists || null) }

    function test_defaults_cover_schema() {
        var d = Lib.defaults(schema)
        for (var k in schema.keys) {
            verify(k in d, k)
            if (schema.keys[k].type !== "derived") verify(v(k, d[k], function () { return true }).ok, k + " default invalid")
        }
        compare(d["focus.durations"], [25, 50, 90])
    }
    function test_type_checks() {
        verify(!v("appearance.glass", 1).ok)
        verify(v("appearance.glass", true).ok)
        verify(!v("bar.tray.max", 2.5).ok)
        verify(!v("bar.tray.max", "3").ok)
        verify(!v("nightLight.from", "7:30").ok)
        verify(v("nightLight.from", "07:30").ok)
        verify(!v("bar.height", 35).ok)
        verify(!v("no.such.key", 1).ok)
    }
    function test_ranges() {
        var e = schema.keys["bar.tray.max"]
        verify(v("bar.tray.max", e.min).ok)
        verify(!v("bar.tray.max", e.max + 1).ok)
        verify(v("idle.dimAfter", 0).ok)           // zeroMeans never
        verify(!v("idle.dimAfter", 10).ok)
        verify(v("notifications.timeout", "auto").ok)
        verify(v("notifications.timeout", 10).ok)
        verify(!v("notifications.timeout", 2).ok)
        verify(!v("notifications.timeout", "soon").ok)
    }
    function test_enums() {
        verify(v("appearance.textScale", 1.1).ok)
        verify(!v("appearance.textScale", 1.2).ok)
        verify(v("spotlight.searchEngine", "kagi").ok)
        verify(v("spotlight.searchEngine", "https://x.test/?q=%s").ok)
        verify(!v("spotlight.searchEngine", "https://x.test/").ok)
        verify(!v("appearance.mode", "sepia").ok)
    }
    function test_nullable() {
        verify(v("weather.location", null).ok)
        verify(v("dnd.schedule", null).ok)
        verify(!v("appearance.mode", null).ok)
        verify(!v("weather.location", { name: "X", lat: "1", lon: 2 }).ok)
    }
    function test_path_inside_home() {
        verify(v("capture.dir", "~/Videos").ok)
        verify(v("capture.dir", "/home/t/x").ok)
        verify(!v("capture.dir", "/etc").ok)
        verify(!v("capture.dir", "~/../other").ok)
        verify(!v("capture.dir", "/home/tt").ok)
    }
    function test_cross_rules_idle_order() {
        var d = Lib.defaults(schema)
        d["idle.dimAfter"] = 600; d["idle.lockAfter"] = 300
        var c = Lib.crossCheck(schema, d)
        compare(c.length, 1); compare(c[0].key, "idle.lockAfter")
        d["idle.lockAfter"] = 0
        compare(Lib.crossCheck(schema, d).length, 0)
        d["idle.lockAfter"] = 900; d["idle.screenOffAfter"] = 900
        compare(Lib.crossCheck(schema, d).length, 0)  // lock <= screen off
    }
    function test_cross_rules_focus_default() {
        var d = Lib.defaults(schema)
        d["focus.default"] = 33
        compare(Lib.crossCheck(schema, d)[0].key, "focus.default")
    }
    function test_load_v1_ignored() {
        var r = Lib.load(schema, '{"bar": {"height": 40}}', home, null)
        verify(r.ok); verify(r.v1)
        compare(Object.keys(r.overrides).length, 0)
    }
    function test_load_unknown_kept() {
        var r = Lib.load(schema, '{"v": 2, "future.key": [1]}', home, null)
        compare(r.unknown["future.key"], [1])
        verify(Lib.serialise(r.overrides, r.unknown).indexOf('"future.key"') > 0)
    }
    function test_load_invalid_value_falls_back() {
        var r = Lib.load(schema, '{"v": 2, "appearance.mode": "sepia", "bar.tray.max": 5}', home, null)
        compare(r.values["appearance.mode"], schema.keys["appearance.mode"]["default"])
        compare(r.problems.length, 1); compare(r.problems[0].key, "appearance.mode")
        compare(r.overrides["bar.tray.max"], 5)
    }
    function test_load_syntax_error() {
        var r = Lib.load(schema, '{"v": 2,\n  "a": }', home, null)
        verify(!r.ok)
        compare(r.error, "line 2, column 8: unexpected \"}\"")
        compare(Lib.load(schema, '{"v": 2', home, null).error, "line 1, column 8: expected , or }")
        compare(r.values["appearance.mode"], schema.keys["appearance.mode"]["default"])
    }
    function test_serialise_only_overrides() {
        var r = Lib.load(schema, '{"v": 2, "appearance.mode": "' + schema.keys["appearance.mode"]["default"] + '"}', home, null)
        compare(Object.keys(r.overrides).length, 0)
        compare(Lib.serialise(r.overrides, r.unknown), '{\n  "v": 2\n}\n')
    }
    function test_serialise_sorted() {
        var t = Lib.serialise({ "z.k": { b: 1, a: [2] }, "a.k": true }, {})
        compare(t, '{\n  "v": 2,\n  "a.k": true,\n  "z.k": {\n    "a": [\n      2\n    ],\n    "b": 1\n  }\n}\n')
        compare(JSON.parse(t)["z.k"].a[0], 2)
    }
    function test_visible_if() {
        var d = Lib.defaults(schema)
        var any = 0
        for (var k in schema.keys) {
            var e = schema.keys[k]
            if (!e.visibleIf) continue
            any++
            verify(e.visibleIf.key in schema.keys, k)
            var c = JSON.parse(JSON.stringify(e)); c.visibleIf = { key: "appearance.mode", equals: d["appearance.mode"] }
            verify(Lib.visible(c, d))
            c.visibleIf = { key: "appearance.mode", notEquals: d["appearance.mode"] }
            verify(!Lib.visible(c, d))
        }
        verify(any > 0)
        verify(Lib.visible({}, d))
    }
    function test_unique_lists() {
        verify(!v("deck.tiles", ["wifi", "wifi"]).ok)
        verify(v("deck.tiles", ["wifi", "dnd"]).ok)
        verify(!v("deck.tiles", ["toaster"]).ok)
        verify(!v("focus.durations", [25, 50]).ok)
        verify(!v("focus.durations", [25, 50, 300]).ok)
    }
    function test_item_ranges() {
        verify(v("dnd.schedule", { from: "22:00", to: "07:00", days: [1, 7] }).ok)
        verify(!v("dnd.schedule", { from: "22:00", to: "07:00", days: [0] }).ok)
        verify(!v("dnd.schedule", { from: "22:00", to: "07:00", days: [2, 2] }).ok)
        verify(!v("dnd.schedule", { from: "25:00", to: "07:00", days: [1] }).ok)
    }
    function test_must_exist() {
        verify(!v("wallpaper.dir", "~/nope", function (p) { return false }).ok)
        verify(v("wallpaper.dir", "~/yes", function (p) { return p === "/home/t/yes" }).ok)
        verify(v("wallpaper.dir", "~/unchecked").ok)       // exists null skips the check
    }
    function test_list_path_inside_home() {
        verify(v("files.roots", ["~", "~/Code"]).ok)
        verify(!v("files.roots", ["~", "/tmp"]).ok)
    }
    function test_migrate() {
        var m = Lib.migrate({ "a": 1 })
        verify(!m.changed); compare(m.values.a, 1)
        Lib.MIGRATIONS["old.k"] = "new.k"
        m = Lib.migrate({ "old.k": 5 })
        verify(m.changed); compare(m.values["new.k"], 5)
        delete Lib.MIGRATIONS["old.k"]
    }
    function test_derived_follows_text_scale() {
        compare(Lib.load(schema, '{"v": 2, "appearance.textScale": 1.25}', home, null).values["bar.height"], 40)
    }
}
