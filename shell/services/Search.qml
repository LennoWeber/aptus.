pragma Singleton
import QtQuick
import Quickshell
import qs.models

// Search backends of the launcher modes.
Singleton {
    id: root
    // Sources per mode (L13): Apps -> DesktopEntries + AiProviders CLI entries (+ windows, calculator, system actions);
    // Web -> BrowserState suggestions; Settings -> settings-schema.json; AI -> none (asks AiProviders); Clipboard -> Clipboard.entries.
    property var appEntries          // from Quickshell DesktopEntries
    property var settingEntries      // list of SettingEntry from settings-schema.json
    property var browser             // BrowserState, set by shell.qml; Web results search through it
    property int maxResults: 8       // launcher.maxResults

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
        if (q === "") return []
        // A local search over a few hundred entries is well below a frame; the heavy backends (web suggestions, clipboard) come later.
        // TODO(phase 7, sections 4/5): Settings (SettingEntry.matches) and web suggestions.
        // TODO(phase 7, section 3): windows, system actions ('wifi off', 'timer 10m') and the AI CLI sessions in Apps mode.
        switch (mode) {
        case Enums.LauncherMode.Apps: {
            const out = []
            const calc = evaluateExpression(q)
            if (calc) out.push(calc)
            return out.concat(searchApps(q))
        }
        case Enums.LauncherMode.Web:
            return [makeResult({
                id: "web:" + q, mode: mode, kind: Enums.ResultKind.WebSuggestion,
                title: q, subtitle: "Search the web", iconName: "web", keyHint: "Enter",
                score: 100,
                run: () => { if (root.browser) root.browser.search(q) }
            })]
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

    function searchWindows(query: string): var {
        // TODO(phase 7, section 3): open windows from Compositor, focus on activate.
        throw new Error("not implemented")
    }

    function searchSettings(query: string): var {
        // TODO(phase 7): use SettingEntry.matches over settings-schema.json; a result opens the entry via SettingsAppState.focusEntry.
        throw new Error("not implemented")
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

    function webSuggestions(query: string): var {
        throw new Error("not implemented")
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

    // 'wifi off', 'timer 10m' and similar.
    function parseSystemAction(query: string): var {
        throw new Error("not implemented")
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
