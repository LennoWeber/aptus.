pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.models

// Search backends of the launcher modes.
Singleton {
    id: root
    // Sources per mode (L13): Apps -> DesktopEntries + AiProviders CLI entries (+ windows, calculator, system actions);
    // Web -> BrowserState suggestions; Settings -> settings-schema.json; AI -> none (asks AiProviders); Clipboard -> Clipboard.entries.
    property var appEntries          // from Quickshell DesktopEntries
    property var settingsState       // SettingsAppState, set by shell.qml; Settings mode searches its entries
    property var browser             // BrowserState, set by shell.qml; Web results search through it
    property var controls            // { network, bluetooth, nightLight, caffeine, focus, timer, lock }, set by shell.qml; system actions drive them
    property int maxResults: 8       // launcher.maxResults
    property bool showOpenWindows: true  // launcher.showOpenWindows

    // Results are real SearchResult objects (they carry their action). The previous batch is destroyed on the next search.
    property var batch: []

    Component {
        id: resultComponent
        SearchResult {}
    }

    function makeResult(props: var): var {
        const r = resultComponent.createObject(root, props)
        batch.push(r)
        return r
    }

    function discardBatch(): void {
        for (const r of batch) r.destroy()
        batch = []
    }

    // Results for a launcher mode, never blocks the UI.
    function runSearch(mode: int, query: string): var {
        if (mode < Enums.LauncherMode.Apps || mode > Enums.LauncherMode.Clipboard) throw new Error("invariant: Search.runSearch: unknown launcher mode")
        if (typeof query !== "string") throw new Error("invariant: Search.runSearch: query must be a string")
        discardBatch()
        const q = query.trim()
        if (mode === Enums.LauncherMode.Clipboard) return searchClipboard(q)
        if (mode === Enums.LauncherMode.Settings) return searchSettings(q)
        if (q === "") return []
        // A local search over a few hundred entries is well below a frame; the heavy backends (web suggestions, clipboard) come later.
        switch (mode) {
        case Enums.LauncherMode.Apps: {
            const out = []
            const calc = evaluateExpression(q)
            if (calc) out.push(calc)
            return out.concat(searchActions(q), searchWindows(q), searchApps(q))
        }
        case Enums.LauncherMode.Web: {
            const out = [makeResult({
                id: "web:" + q, mode: mode, kind: Enums.ResultKind.WebSuggestion,
                title: q, subtitle: "Search the web", iconName: "web", keyHint: "Enter",
                score: 100,
                run: () => { if (root.browser) root.browser.search(q) }
            })]
            // Suggestions only count for the text they were fetched for; an old answer is not shown.
            if (WebSuggest.forQuery === q) for (const phrase of WebSuggest.suggestions) {
                if (phrase.toLowerCase() === q.toLowerCase()) continue
                out.push(makeResult({
                    id: "web:" + phrase, mode: mode, kind: Enums.ResultKind.WebSuggestion,
                    title: phrase, subtitle: "Suggestion", iconName: "web", keyHint: "Enter",
                    score: 90 - out.length,
                    run: () => { if (root.browser) root.browser.search(phrase) }
                }))
            }
            return out
        }
        default:
            return []
        }
    }

    function searchApps(query: string): var {
        const apps = DesktopEntries.applications.values
        const scored = []
        for (const e of apps) {
            if (e.noDisplay) continue
            let s = fuzzyScore(e.name, query)
            const g = e.genericName ? fuzzyScore(e.genericName, query) * 0.6 : 0
            const k = e.keywords && e.keywords.length > 0 ? fuzzyScore(e.keywords.join(" "), query) * 0.5 : 0
            s = Math.max(s, g, k)
            if (s <= 0) continue
            scored.push(makeResult({
                id: "app:" + e.id, mode: Enums.LauncherMode.Apps, kind: Enums.ResultKind.App,
                title: e.name, subtitle: e.genericName ? e.genericName : "App", iconName: e.icon,
                score: s,
                run: () => e.execute()
            }))
        }
        return rank(scored, query).slice(0, maxResults)
    }

    // System actions typed as a command: "wifi off", "bluetooth", "night light on", "lock", "timer 10m", "pomodoro".
    // Switches take an optional trailing on/off; without it the result flips the current state.
    function searchActions(query: string): var {
        const c = controls
        if (!c) return []
        const out = []
        const add = (id, title, subtitle, run) => out.push(makeResult({
            id: "action:" + id, mode: Enums.LauncherMode.Apps, kind: Enums.ResultKind.Action,
            title: title, subtitle: subtitle, keyHint: "Enter", score: 500, run: run
        }))
        const q = query.toLowerCase()

        const timerText = q.match(/^timer\s+(.+)$/)
        if (timerText) {
            const sec = parseDuration(timerText[1])
            if (sec !== null) add("timer", "Start timer: " + describeDuration(sec), "Timer", () => c.timer.startTimer(sec))
        }
        if (c.timer && c.timer.running && fuzzyScore("stop timer", q) >= 55)
            add("timer-stop", "Stop timer", "Timer", () => c.timer.reset())
        if (fuzzyScore("pomodoro", q) >= 55) add("pomodoro", "Start pomodoro", "Timer", () => c.timer.startPomodoro())
        if (fuzzyScore("lock screen", q) >= 55) add("lock", "Lock screen", "Session", () => c.lock.lock())

        const switches = [
            { id: "wifi", name: "Wi-Fi", keys: ["wifi", "wi-fi"], target: c.network, get: t => t.wifiEnabled, set: (t, on) => t.setWifiEnabled(on) },
            { id: "bluetooth", name: "Bluetooth", keys: ["bluetooth"], target: c.bluetooth, get: t => t.powered, set: (t, on) => t.setPowered(on) },
            { id: "nightlight", name: "Night light", keys: ["night light", "nightlight"], target: c.nightLight, get: t => t.enabled, set: (t, on) => t.setEnabled(on) },
            { id: "caffeine", name: "Caffeine", keys: ["caffeine"], target: c.caffeine, get: t => t.active, set: (t, on) => t.setActive(on) },
            { id: "focus", name: "Focus", keys: ["focus", "do not disturb"], target: c.focus, get: t => t.active, set: (t, on) => t.setActive(on) }
        ]
        const verb = q.match(/^(.*?)\s+(on|off)$/)
        const subject = verb ? verb[1] : q
        for (const sw of switches) {
            if (!sw.target || subject.length < 2 || !sw.keys.some(k => fuzzyScore(k, subject) >= 55)) continue
            const now = sw.get(sw.target)
            const target = verb ? verb[2] === "on" : !now
            add(sw.id, "Turn " + sw.name + (target ? " on" : " off"), target === now ? "Already " + (now ? "on" : "off") : "Currently " + (now ? "on" : "off"),
                () => sw.set(sw.target, target))
        }
        return out
    }

    // "10m", "1h30", "1h 30m", "90s", "25" (minutes) as seconds; null for anything else, zero or over a day.
    function parseDuration(text: string): var {
        // Units are explicit ("10m", "1h30m", "90s"); a bare number is minutes, also after hours ("1h30").
        const t = text.trim()
        const m = t.match(/^(?:(\d+)\s*h)?\s*(?:(\d+)\s*m(?:in)?)?\s*(?:(\d+)\s*s)?$/) || t.match(/^(?:(\d+)\s*h\s*)?(\d+)()$/)
        if (!m || (m[1] === undefined && m[2] === undefined && m[3] === undefined)) return null
        const sec = Number(m[1] || 0) * 3600 + Number(m[2] || 0) * 60 + Number(m[3] || 0)
        return sec > 0 && sec <= 86400 ? sec : null
    }

    function describeDuration(sec: int): string {
        const h = Math.floor(sec / 3600)
        const mi = Math.floor((sec % 3600) / 60)
        const s = sec % 60
        return [h ? h + " h" : "", mi ? mi + " min" : "", s ? s + " s" : ""].filter(x => x).join(" ")
    }

    // Open windows (Hyprland), matched on title and class; Enter focuses the window.
    function searchWindows(query: string): var {
        if (!showOpenWindows) return []
        const out = []
        for (const t of Hyprland.toplevels.values) {
            const cls = t.lastIpcObject && t.lastIpcObject.class ? t.lastIpcObject.class : ""
            const s = Math.max(fuzzyScore(t.title || "", query), fuzzyScore(cls, query) * 0.8)
            if (s <= 0) continue
            out.push(makeResult({
                id: "window:" + t.address, mode: Enums.LauncherMode.Apps, kind: Enums.ResultKind.Window,
                title: t.title || cls, subtitle: "Open window" + (cls ? " · " + cls : ""), iconName: cls.toLowerCase(),
                score: s + 5,
                run: () => Compositor.focusWindow(t.address)
            }))
        }
        return out
    }

    // Entries of the settings app; Enter opens the window on that entry. An empty query lists the categories.
    function searchSettings(query: string): var {
        const st = settingsState
        if (!st) return []
        if (query === "") {
            return st.categories.map((c, i) => makeResult({
                id: "settings-category:" + c.id, mode: Enums.LauncherMode.Settings, kind: Enums.ResultKind.Setting,
                title: c.title, subtitle: "Category", keyHint: "Enter", score: 100 - i,
                run: () => st.openWindow(c.id)
            }))
        }
        const scored = st.entries.filter(e => st.matches(e, query)).map(e => makeResult({
            id: "setting:" + e.id, mode: Enums.LauncherMode.Settings, kind: Enums.ResultKind.Setting,
            title: e.title, subtitle: (st.categories.find(c => c.id === e.category) || { title: "" }).title, keyHint: "Enter",
            score: 10 + fuzzyScore(e.title, query),
            run: () => st.focusEntry(e.id)
        }))
        return rank(scored, query).slice(0, maxResults)
    }

    // The history, newest first; text is filtered by the query. An empty query lists the latest entries.
    function searchClipboard(query: string): var {
        const q = query.toLowerCase()
        return Clipboard.entries.filter(e => q === "" || e.preview.toLowerCase().indexOf(q) >= 0).slice(0, maxResults).map((e, i) => makeResult({
            id: "clip:" + e.id, mode: Enums.LauncherMode.Clipboard, kind: Enums.ResultKind.ClipboardItem,
            title: e.preview, subtitle: e.kind === "image" ? "Image" : "", keyHint: "Enter copies",
            actionId: e.id, score: 1000 - i,
            run: () => Clipboard.copy(e.id)
        }))
    }


    // Calculator results such as '12*8'. Returns one result, or null if the text is not an expression.
    function evaluateExpression(query: string): var {
        const expr = query.replace(/,/g, ".").replace(/\s+/g, "")
        // Only digits, operators and brackets, and at least one operator that is not a leading sign.
        if (!/^[0-9+\-*\/().%^]+$/.test(expr) || !/[0-9][+\-*\/%^]/.test(expr)) return null
        const value = calc(expr)
        if (value === null || !isFinite(value)) return null
        const text = String(Number(value.toPrecision(12)))
        return makeResult({
            id: "calc:" + expr, mode: Enums.LauncherMode.Apps, kind: Enums.ResultKind.Calculation,
            title: text, subtitle: query.trim() + " =", iconName: "calc", keyHint: "Enter copies",
            score: 1000,
            run: () => Quickshell.execDetached(["wl-copy", text])
        })
    }

    // A small recursive-descent calculator: + - * / % ^, brackets, unary minus. No eval.
    function calc(expr: string): var {
        let pos = 0
        let failed = false
        const peek = () => expr[pos]
        function number() {
            const start = pos
            while (pos < expr.length && /[0-9.]/.test(expr[pos])) pos++
            if (start === pos) { failed = true; return 0 }
            const n = Number(expr.slice(start, pos))
            if (isNaN(n)) failed = true
            return n
        }
        function atom() {
            if (peek() === "(") {
                pos++
                const v = sum()
                if (peek() === ")") pos++
                else failed = true
                return v
            }
            if (peek() === "-") { pos++; return -atom() }
            if (peek() === "+") { pos++; return atom() }
            return number()
        }
        function power() {
            const base = atom()
            if (peek() === "^") { pos++; return Math.pow(base, power()) }
            return base
        }
        function product() {
            let v = power()
            while (peek() === "*" || peek() === "/" || peek() === "%") {
                const op = expr[pos++]
                const r = power()
                v = op === "*" ? v * r : op === "/" ? v / r : v % r
            }
            return v
        }
        function sum() {
            let v = product()
            while (peek() === "+" || peek() === "-") {
                const op = expr[pos++]
                const r = product()
                v = op === "+" ? v + r : v - r
            }
            return v
        }
        const v = sum()
        return failed || pos !== expr.length ? null : v
    }


    // 0 = no match, up to 100 = exact. Prefix beats word start beats substring beats initials beats scattered letters.
    function fuzzyScore(text: string, query: string): real {
        if (typeof text !== "string" || typeof query !== "string") throw new Error("invariant: Search.fuzzyScore: text and query must be strings")
        const t = text.toLowerCase()
        const q = query.toLowerCase().trim()
        if (q === "" || t === "") return 0
        if (t === q) return 100
        if (t.startsWith(q)) return 90 - Math.min(20, t.length - q.length) * 0.5
        const idx = t.indexOf(q)
        if (idx >= 0) {
            const wordStart = idx === 0 || t[idx - 1] === " " || t[idx - 1] === "-" || t[idx - 1] === "."
            return (wordStart ? 80 : 55) - Math.min(15, idx) * 0.3
        }
        const initials = t.split(/[\s\-_.]+/).filter(w => w).map(w => w[0]).join("")
        if (initials.startsWith(q)) return 70
        let qi = 0
        let last = -1
        let gaps = 0
        for (let ti = 0; ti < t.length && qi < q.length; ti++) {
            if (t[ti] === q[qi]) {
                if (last >= 0) gaps += ti - last - 1
                last = ti
                qi++
            }
        }
        if (qi < q.length) return 0
        return Math.max(1, 40 - gaps * 2)
    }

    // Sort by score (high first), then alphabetically; drop results with no score.
    function rank(items: var, query: string): var {
        if (!Array.isArray(items)) throw new Error("invariant: Search.rank: items must be an array")
        return items.filter(r => r.score > 0).sort((a, b) => b.score - a.score || a.title.localeCompare(b.title))
    }
}
