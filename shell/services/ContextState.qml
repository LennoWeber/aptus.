import QtQuick
import qs.models

// What the middle of the bar may show, as plain objects: { id, text, severity, priority, tileId }.
// ContextZone picks the one with the highest priority; the window title is its fallback.
QtObject {
    id: root

    property var battery   // BatteryState
    property var timer     // TimerState
    property var media     // MediaState
    property bool enabled: true

    readonly property var items: {
        if (!enabled) return []
        const list = []
        const b = battery
        if (b && b.present && b.discharging && b.percent <= b.criticalBelowPercent)
            list.push({ id: "battery", text: "Battery " + Math.round(b.percent) + "%", severity: Enums.Severity.Critical, priority: 90, tileId: Enums.TileId.PowerProfile })
        const t = timer
        if (t && t.running)
            list.push({ id: "timer", text: formatTime(t.remainingSec) + " " + t.phaseName, severity: Enums.Severity.Neutral, priority: 60, tileId: Enums.TileId.Timer })
        const n = Notifications.popupItems
        if (n.length > 0)
            list.push({ id: "notification", text: n[0].summary || n[0].appName, severity: Enums.Severity.Neutral, priority: 40, tileId: Enums.TileId.Notifications })
        const m = media
        if (m && m.available && m.playing && m.title !== "")
            list.push({ id: "media", text: m.artist !== "" ? m.title + " · " + m.artist : m.title, severity: Enums.Severity.Neutral, priority: 30, tileId: Enums.TileId.Media })
        return list
    }

    function formatTime(sec: int): string {
        const s = Math.max(0, sec)
        const h = Math.floor(s / 3600)
        const mm = Math.floor((s % 3600) / 60)
        const ss = s % 60
        const two = v => (v < 10 ? "0" : "") + v
        return h > 0 ? h + ":" + two(mm) + ":" + two(ss) : mm + ":" + two(ss)
    }
}
