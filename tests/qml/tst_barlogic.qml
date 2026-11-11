// The bar's layout and status logic (surfaces/bar/js/bar.js, bar.md §2–§7, §9).
import QtQuick
import QtTest
import "../../shell/surfaces/bar/js/bar.js" as B

TestCase {
    name: "barlogic"

    readonly property var t: ({ batteryWarnPercent: 15, batteryCritPercent: 7, batteryShowPercentBelow: 30,
                                titleMaxWidth: 420, titleMinWidth: 120, narrowTitleMaxWidth: 240 })
    function input(extra) {
        const i = {
            battery: { hasBattery: true, percentage: 64, charging: false, timeToEmpty: 11400, timeToFull: 0, profile: "balanced" },
            volume: { level: 0.4, muted: false, device: "Speakers" },
            bluetooth: { available: true, enabled: true, connected: [] },
            network: { kind: "wifi", online: true, ssid: "Home", strength: 82, vpn: "" },
            dnd: { on: false, until: "", focus: false },
            privacy: { mic: [], camera: [], screencast: false },
            settings: { batteryPercent: "auto", bluetooth: "connected" }
        }
        for (const k in extra) i[k] = extra[k]
        return i
    }

    function test_status_items_order_and_visibility() {
        compare(B.statusItems(input({}), false, t).map(i => i.id), ["battery", "volume", "network"])
        const all = B.statusItems(input({
            bluetooth: { available: true, enabled: true, connected: [{ name: "Buds", battery: 70 }] },
            network: { kind: "wifi", online: true, ssid: "Home", strength: 82, vpn: "work" },
            dnd: { on: true, until: "18:00", focus: false },
            privacy: { mic: ["zoom"], camera: ["zoom"], screencast: true } }), false, t)
        compare(all.map(i => i.id), B.STATUS_ORDER)
        compare(all[2].tooltip, "Buds · 70 %")
        compare(all[3].extra, "vpn_key")
        compare(all[4].tooltip, "Do not disturb until 18:00")
        // focus owns DND's look: no DND item while focus runs
        verify(B.statusItems(input({ dnd: { on: true, until: "", focus: true } }), false, t).every(i => i.id !== "dnd"))
        // the percentage: below 30 % or charging under "auto"; always / never
        compare(B.statusItems(input({}), false, t)[0].text, "")
        compare(B.statusItems(input({ battery: { hasBattery: true, percentage: 20, charging: false, timeToEmpty: 0, timeToFull: 0, profile: "" } }), false, t)[0].text, "20 %")
        compare(B.statusItems(input({ settings: { batteryPercent: "always", bluetooth: "connected" } }), false, t)[0].text, "64 %")
        compare(B.statusItems(input({ battery: { hasBattery: true, percentage: 20, charging: false, timeToEmpty: 0, timeToFull: 0, profile: "" },
                                      settings: { batteryPercent: "never", bluetooth: "connected" } }), false, t)[0].text, "")
        // "always": the Bluetooth item also while nothing is connected
        verify(B.statusItems(input({ settings: { batteryPercent: "auto", bluetooth: "always" } }), false, t).some(i => i.id === "bluetooth"))
        // no battery: no item
        verify(B.statusItems(input({ battery: { hasBattery: false } }), false, t).every(i => i.id !== "battery"))
    }
    function test_status_quiet() {
        compare(B.statusItems(input({}), true, t).length, 0)
        const q = B.statusItems(input({ battery: { hasBattery: true, percentage: 25, charging: false, timeToEmpty: 0, timeToFull: 0, profile: "" },
                                        privacy: { mic: ["zoom"], camera: [], screencast: false } }), true, t)
        compare(q.map(i => i.id), ["battery", "mic"])
    }
    function test_battery_tooltip() {
        compare(B.batteryTooltip({ percentage: 64, charging: false, timeToEmpty: 11400, timeToFull: 0, profile: "balanced" }),
                "64 % · 3 h 10 min left · Balanced")
        compare(B.batteryTooltip({ percentage: 80, charging: true, timeToEmpty: 0, timeToFull: 0, profile: "" }), "80 % · Charging")
    }
    function test_collapse_levels() {
        compare(B.collapseLevel(300, 200, 100, 400), 0)
        compare(B.collapseLevel(500, 300, 100, 400), 1)
        compare(B.collapseLevel(500, 450, 100, 400), 2)
    }
    function test_title_throttle() {
        let th = { changes: [], shownAt: 0 }
        for (let i = 0; i < 4; i++) th = B.noteTitleChange(th, 1000 + i * 100)
        compare(B.titleDelay(th, 1300, 4, 250), 0)                       // 4 a second: no delay
        th = B.noteTitleChange({ changes: th.changes, shownAt: 1300 }, 1350)
        compare(B.titleDelay(th, 1350, 4, 250), 200)                      // the 5th waits for 250 ms after the last shown
        compare(B.noteTitleChange({ changes: [0, 100], shownAt: 0 }, 5000).changes, [5000])   // old ones drop out
    }
    function test_tray_layout() {
        const items = [{ id: "a" }, { id: "b" }, { id: "c" }, { id: "d" }]
        const l = B.trayLayout(items, 2, ["b"], ["d"])
        compare(l.shown.map(i => i.id), ["d", "a"])
        compare(l.overflow.map(i => i.id), ["c"])
        compare(B.trayLayout(items, 8, [], []).overflow.length, 0)
    }
    function test_deck_args() {
        compare(B.deckArgs("sound", false), { section: "sound" })
        compare(B.deckArgs("sound", true), { page: "sound" })
    }
    function test_menus() {
        const w = B.windowMenu({ floating: false, pinned: false, fullscreen: false, workspace: 3 }, ["eDP-1"], "eDP-1")
        compare(w[0].label, "Float")
        verify(w[1].enabled === false)                                   // pin needs a floating window
        verify(w.find(r => r.id === "monitor").enabled === false)        // no other monitor
        verify(w.find(r => r.id === "workspace").submenu[2].enabled === false)   // its own workspace
        verify(w[w.length - 1].risk)
        const p = B.pillMenu({ id: 2, windows: 3 }, ["eDP-1", "DP-3"], "eDP-1")
        compare(p.find(r => r.id === "monitor").submenu, [{ id: "mon:DP-3", label: "DP-3" }])
        compare(p.find(r => r.id === "closeall").confirm, "Close 3 windows?")
        verify(B.pillMenu({ id: 2, windows: 0 }, [], "eDP-1").find(r => r.id === "closeall").enabled === false)
        compare(B.workspaceTooltip({ id: 2, name: "" }, ["Zen", "kitty"]), "2 · Zen, kitty")
        compare(B.windowGlyphs({ floating: true, pinned: true, fullscreen: false }), ["picture_in_picture", "push_pin"])
    }
    function test_title_width() {
        compare(B.titleWidth(1000, false, t), 420)
        compare(B.titleWidth(1000, true, t), 240)
        compare(B.titleWidth(300, false, t), 300)
        compare(B.titleWidth(100, false, t), 0)                          // below the minimum: hidden
    }

    // An invariant of bar refuses the call (any other exception is not a refusal).
    function refuses(f) {
        try { f() } catch (e) { return String(e.message).indexOf("bar invariant:") === 0 }
        return false
    }
    function accepts(f) {
        try { f() } catch (e) { return false }
        return true
    }

    // Found in review: one step per 120 of angleDelta, small deltas add up, a turn drops the rest.
    function test_wheel_steps() {
        compare(B.wheelSteps(0, 120), { steps: 1, carry: 0 })
        compare(B.wheelSteps(0, -240), { steps: -2, carry: 0 })
        let r = { steps: 0, carry: 0 }, total = 0
        for (let i = 0; i < 16; i++) { r = B.wheelSteps(r.carry, 15); total += r.steps }
        compare(total, 2)                                   // 16 × 15 = 240: two steps, not sixteen
        compare(r.carry, 0)
        r = B.wheelSteps(90, -30)                           // the direction turned: the 90 is dropped
        compare(r, { steps: 0, carry: -30 })
        compare(B.wheelSteps(NaN, 120).steps, 1)
    }
    function test_invariants_reject_broken_state() {
        verify(refuses(() => B.statusItems(input({ settings: { batteryPercent: "sometimes", bluetooth: "connected" } }), false, t)))
        verify(refuses(() => B.statusItems(input({ settings: { batteryPercent: "auto", bluetooth: undefined } }), false, t)))
        verify(refuses(() => B.statusItems(input({}), false, Object.assign({}, t, { batteryCritPercent: 20 }))))
        verify(refuses(() => B.titleWidth(1000, false, Object.assign({}, t, { narrowTitleMaxWidth: 500 }))))
        verify(refuses(() => B.collapseLevel(-1, 0, 0, 400)))
        verify(refuses(() => B.noteTitleChange(null, 0)))
        verify(refuses(() => B.titleDelay({ changes: [], shownAt: 0 }, 0, 0, 250)))
        verify(refuses(() => B.trayLayout([], -1, [], [])))
        verify(refuses(() => B.trayLayout([], 1.5, [], [])))
        verify(refuses(() => B.trayLayout([], 3, "a", [])))
        verify(refuses(() => B.deckArgs("", false)))
        verify(refuses(() => B.windowMenu(null, [], "eDP-1")))
        verify(refuses(() => B.pillMenu({ id: -98, windows: 1, special: true }, [], "eDP-1")))
        verify(!refuses(() => B.pillMenu({ id: -1337, windows: 1, special: false }, [], "eDP-1")))   // a named workspace
        // menu rows: an id and a label each, each id once (separators aside), submenus too
        verify(accepts(() => B.checkMenu([{ id: "a", label: "A" }, { separator: true }, { id: "b", label: "B", submenu: [{ id: "c", label: "C" }] }])))
        verify(refuses(() => B.checkMenu([{ id: "a", label: "A" }, { id: "a", label: "B" }])))
        verify(refuses(() => B.checkMenu([{ id: "a", label: "" }])))
        verify(refuses(() => B.checkMenu([{ id: "b", label: "B", submenu: [{ id: "", label: "C" }] }])))
    }
}
