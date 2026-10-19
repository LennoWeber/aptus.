import QtQuick
import Quickshell
import Quickshell.Io
import qs.models

// Claude usage shown in the control center. The numbers come from ~/.claude/usage-cache.json, which Claude Code
// (or a usage plugin) keeps up to date; aptus only reads it and never touches a login token. The age of the data
// is shown, so old numbers are never passed off as current.
QtObject {
    id: root

    property string cachePath: Quickshell.env("HOME") + "/.claude/usage-cache.json"

    property bool connected                 // the file exists and has the 5 h and 7 d windows
    property string provider: "Claude"
    property real fiveHour: 0               // 0..1
    property real sevenDay: 0               // 0..1
    property var fiveHourResetsAt           // Date or null
    property var sevenDayResetsAt
    property var breakdown: []              // { name, percent } of the 7 day window
    property real cachedAt: 0               // seconds since epoch
    property real now: Date.now() / 1000    // refreshed with the file

    readonly property int ageMinutes: cachedAt > 0 ? Math.max(0, Math.round((now - cachedAt) / 60)) : -1
    readonly property bool stale: ageMinutes > 30
    readonly property int severity: severityOf(Math.max(fiveHour, sevenDay))

    function severityOf(fraction: real): int {
        return fraction >= 0.9 ? Enums.Severity.Critical : fraction >= 0.7 ? Enums.Severity.Warn : Enums.Severity.Neutral
    }

    // "1 h 20 min", "3 d 4 h": the time until a reset.
    function untilText(when: var): string {
        if (!when) return ""
        const minutes = Math.max(0, Math.round((when.getTime() / 1000 - now) / 60))
        if (minutes < 60) return minutes + " min"
        if (minutes < 60 * 24) return Math.floor(minutes / 60) + " h " + (minutes % 60) + " min"
        return Math.floor(minutes / 1440) + " d " + Math.floor((minutes % 1440) / 60) + " h"
    }

    function ageText(): string {
        if (ageMinutes < 0) return ""
        if (ageMinutes < 2) return "just now"
        if (ageMinutes < 90) return ageMinutes + " min ago"
        return Math.round(ageMinutes / 60) + " h ago"
    }

    function refresh(): void {
        now = Date.now() / 1000
        cacheFile.reload()
    }

    function load(text: string): void {
        try {
            const cache = JSON.parse(text)
            const d = cache.data
            if (!d || !d.five_hour || !d.seven_day) { connected = false; return }
            fiveHour = d.five_hour.utilization / 100
            sevenDay = d.seven_day.utilization / 100
            fiveHourResetsAt = d.five_hour.resets_at ? new Date(d.five_hour.resets_at) : null
            sevenDayResetsAt = d.seven_day.resets_at ? new Date(d.seven_day.resets_at) : null
            breakdown = d.seven_day_breakdown && d.seven_day_breakdown.rows ? d.seven_day_breakdown.rows.map(r => ({ name: r.display_name, percent: r.percent })) : []
            cachedAt = cache.cached_at || 0
            connected = true
        } catch (e) {
            connected = false
        }
    }

    property FileView cacheFile: FileView {
        path: root.cachePath
        printErrors: false
        watchChanges: true
        onLoaded: root.load(text())
        onLoadFailed: root.connected = false
        onFileChanged: reload()
    }

    // The age text and reset countdowns move with the clock.
    property Timer clock: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.now = Date.now() / 1000
    }
}
