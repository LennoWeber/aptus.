import QtQuick
import Quickshell

// Calendar state for the control center tile and the clock dropdown.
Scope {
    id: root

    property string sourceKind   // "ics" | "google"
    property bool connected      // account/feed reachable
    property string accountLabel // e.g. the Google account address
    property var today: new Date()  // Date
    property var selectedDate: new Date()  // Date
    property var events: []      // list of { id, title, start, end, allDay, calendarName }
    property var sources: []     // list of { name, url }: private iCal addresses (settings calendar.sources), read-only
    property string error
    readonly property int horizonDays: 400   // repeating events are expanded this far ahead

    onSourcesChanged: refresh()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        onDateChanged: root.today = clock.date
    }

    // Read-only private iCal addresses, all merged into one list. Google sign-in comes later.
    // Without an address there are no events.
    property int generation: 0   // answers of an older refresh are ignored

    function refresh(): void {
        const list = (sources || []).filter(s => s && s.url)
        generation += 1
        if (list.length === 0) {
            events = []
            connected = false
            error = ""
            return
        }
        const mine = generation
        const results = {}
        let pending = list.length
        let failed = 0
        const finish = () => {
            if (mine !== root.generation) return
            const all = []
            for (const k in results) for (const e of results[k]) all.push(e)
            all.sort((a, b) => a.start - b.start)
            root.events = all
            console.log("aptus: calendar " + all.length + " events from " + (list.length - failed) + " of " + list.length + " sources")
            root.connected = failed < list.length
            root.error = failed > 0 ? (failed === list.length ? "Calendar not reachable" : failed + " calendar(s) not reachable") : ""
        }
        list.forEach((src, index) => {
            const req = new XMLHttpRequest()
            req.onreadystatechange = () => {
                if (req.readyState !== XMLHttpRequest.DONE) return
                try {
                    if (req.status !== 200) throw new Error("status " + req.status)
                    results[index] = root.parseIcs(req.responseText).map(e => Object.assign(e, { calendarName: src.name || "" }))
                } catch (e) {
                    failed += 1
                    results[index] = []
                }
                pending -= 1
                if (pending === 0) finish()
            }
            req.open("GET", src.url)
            req.send()
        })
    }

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: root.sources && root.sources.length > 0
        onTriggered: root.refresh()
    }

    // "20261019" (all day), "20261019T093000" (local) or "20261019T093000Z" (UTC).
    function parseIcsDate(value: string): var {
        const m = value.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/)
        if (!m) return null
        if (m[4] === undefined) return { date: new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3])), allDay: true }
        const parts = [Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5]), Number(m[6])]
        return { date: m[7] ? new Date(Date.UTC(...parts)) : new Date(...parts), allDay: false }
    }

    function unescapeIcs(text: string): string {
        return text.replace(/\\n/gi, "\n").replace(/\\([,;\\])/g, "$1")
    }

    // A small iCal reader: VEVENT with SUMMARY, DTSTART, DTEND and simple RRULE (DAILY, WEEKLY, MONTHLY, YEARLY with INTERVAL, COUNT, UNTIL).
    // Time zone names (TZID) are read as local time.
    function parseIcs(text: string): var {
        const lines = text.replace(/\r?\n[ \t]/g, "").split(/\r?\n/)
        const out = []
        const windowStart = new Date(Date.now() - 31 * 86400000)
        const windowEnd = new Date(Date.now() + horizonDays * 86400000)
        let ev = null
        for (const line of lines) {
            if (line === "BEGIN:VEVENT") { ev = {}; continue }
            if (line === "END:VEVENT") {
                if (ev && ev.start) expandEvent(ev, out, windowStart, windowEnd)
                ev = null
                continue
            }
            if (!ev) continue
            const colon = line.indexOf(":")
            if (colon < 0) continue
            const name = line.slice(0, colon).split(";")[0]
            const value = line.slice(colon + 1)
            if (name === "SUMMARY") ev.title = unescapeIcs(value)
            else if (name === "UID") ev.uid = value
            else if (name === "DTSTART") ev.start = parseIcsDate(value)
            else if (name === "DTEND") ev.end = parseIcsDate(value)
            else if (name === "RRULE") ev.rule = value
            else if (name === "EXDATE") ev.exdates = (ev.exdates || []).concat(value.split(","))
        }
        out.sort((a, b) => a.start - b.start)
        return out
    }

    function expandEvent(ev: var, out: var, windowStart: var, windowEnd: var): void {
        const start = ev.start.date
        const length = ev.end ? ev.end.date.getTime() - start.getTime() : 0
        const base = { id: ev.uid || String(start.getTime()), title: ev.title || "(no title)", allDay: ev.start.allDay, calendarName: "" }
        const add = d => { if (d >= windowStart && d <= windowEnd) out.push(Object.assign({}, base, { start: d, end: new Date(d.getTime() + length) })) }
        if (!ev.rule) { add(start); return }
        const r = {}
        for (const kv of ev.rule.split(";")) { const [k, v] = kv.split("="); r[k] = v }
        const interval = Math.max(1, Number(r.INTERVAL) || 1)
        const until = r.UNTIL ? parseIcsDate(r.UNTIL) : null
        const limit = Number(r.COUNT) || 100000
        const skip = (ev.exdates || []).map(x => { const p = parseIcsDate(x); return p ? p.date.getTime() : 0 })
        for (let i = 0, made = 0; made < limit && i < 4000; i++) {
            const d = new Date(start)
            if (r.FREQ === "DAILY") d.setDate(d.getDate() + i * interval)
            else if (r.FREQ === "WEEKLY") d.setDate(d.getDate() + i * 7 * interval)
            else if (r.FREQ === "MONTHLY") d.setMonth(d.getMonth() + i * interval)
            else if (r.FREQ === "YEARLY") d.setFullYear(d.getFullYear() + i * interval)
            else { add(start); return }
            if (d > windowEnd || (until && d > until.date)) break
            made++
            if (skip.indexOf(d.getTime()) < 0) add(d)
        }
    }

    function selectDate(date: var): void {
        selectedDate = date
    }

    function eventsOn(date: var): var {
        return events.filter(e => {
            const s = new Date(e.start)
            return s.getFullYear() === date.getFullYear() && s.getMonth() === date.getMonth() && s.getDate() === date.getDate()
        })
    }

    // 6 weeks x 7 days for the month of `anchor`, Monday first.
    function monthGrid(anchor: var): var {
        const first = new Date(anchor.getFullYear(), anchor.getMonth(), 1)
        const offset = (first.getDay() + 6) % 7
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - offset + i)
            out.push({ date: d, day: d.getDate(), inMonth: d.getMonth() === anchor.getMonth() })
        }
        return out
    }
}
