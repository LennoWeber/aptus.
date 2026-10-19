pragma Singleton
import QtQuick
import qs.models

// Every control center tile with its fixed size, and the packing of a user order onto the grid.
QtObject {
    readonly property int columns: 6
    readonly property int minRows: 3

    // The order here is the default order (see config/settings.json).
    readonly property var entries: [
        { key: "audio", tileId: Enums.TileId.Audio, title: "Sound", columnSpan: 2, rowSpan: 1 },
        { key: "display", tileId: Enums.TileId.Display, title: "Display", columnSpan: 2, rowSpan: 1 },
        { key: "network", tileId: Enums.TileId.Network, title: "Network", columnSpan: 1, rowSpan: 1 },
        { key: "bluetooth", tileId: Enums.TileId.Bluetooth, title: "Bluetooth", columnSpan: 1, rowSpan: 1 },
        { key: "power", tileId: Enums.TileId.PowerProfile, title: "Power", columnSpan: 1, rowSpan: 1 },
        { key: "caffeine", tileId: Enums.TileId.Caffeine, title: "Caffeine", columnSpan: 1, rowSpan: 1 },
        { key: "focus", tileId: Enums.TileId.Focus, title: "Focus", columnSpan: 1, rowSpan: 1 },
        { key: "vpn", tileId: Enums.TileId.Vpn, title: "VPN", columnSpan: 1, rowSpan: 1 },
        { key: "hotspot", tileId: Enums.TileId.Hotspot, title: "Hotspot", columnSpan: 1, rowSpan: 1 },
        { key: "capture", tileId: Enums.TileId.Capture, title: "Capture", columnSpan: 1, rowSpan: 1 },
        { key: "timer", tileId: Enums.TileId.Timer, title: "Timer", columnSpan: 2, rowSpan: 1 },
        { key: "weather", tileId: Enums.TileId.Weather, title: "Weather", columnSpan: 2, rowSpan: 1 },
        { key: "notifications", tileId: Enums.TileId.Notifications, title: "Notifications", columnSpan: 2, rowSpan: 1 },
        { key: "media", tileId: Enums.TileId.Media, title: "Media", columnSpan: 2, rowSpan: 2 },
        { key: "calendar", tileId: Enums.TileId.Calendar, title: "Calendar", columnSpan: 2, rowSpan: 2 },
        { key: "aiusage", tileId: Enums.TileId.AiUsage, title: "AI usage", columnSpan: 2, rowSpan: 1 },
        { key: "system", tileId: Enums.TileId.SystemMonitor, title: "System", columnSpan: 2, rowSpan: 1 }
    ]

    function titleOf(tileId: int): string {
        const e = entries.find(x => x.tileId === tileId)
        return e ? e.title : ""
    }

    // A saved order as a complete list of { key, visible }: unknown and repeated keys are dropped,
    // tiles added to the shell later appear at the end.
    function normalize(saved: var): var {
        const out = []
        const seen = {}
        for (const s of Array.from(saved || [])) {
            const key = typeof s === "string" ? s : (s ? s.key : "")
            if (seen[key] || !entries.some(e => e.key === key)) continue
            seen[key] = true
            out.push({ key: key, visible: typeof s === "string" || s.visible !== false })
        }
        for (const e of entries) if (!seen[e.key]) out.push({ key: e.key, visible: true })
        return out
    }

    // Visible tiles in the saved order, each in the first free place of the grid (row by row).
    // Result: { rows, tiles: [{ tileId, title, column, row, columnSpan, rowSpan }] }
    function layout(saved: var): var {
        const taken = []   // taken[row][column]
        const fits = (r, c, w, h) => {
            if (c + w > columns) return false
            for (let y = r; y < r + h; y++) for (let x = c; x < c + w; x++) if (taken[y] && taken[y][x]) return false
            return true
        }
        const tiles = []
        let rows = 0
        for (const item of normalize(saved)) {
            if (!item.visible) continue
            const e = entries.find(x => x.key === item.key)
            let r = 0, c = 0
            while (!fits(r, c, e.columnSpan, e.rowSpan)) {
                if (++c >= columns) { c = 0; r++ }
            }
            for (let y = r; y < r + e.rowSpan; y++) {
                taken[y] = taken[y] || []
                for (let x = c; x < c + e.columnSpan; x++) taken[y][x] = true
            }
            tiles.push({ tileId: e.tileId, title: e.title, column: c, row: r, columnSpan: e.columnSpan, rowSpan: e.rowSpan })
            rows = Math.max(rows, r + e.rowSpan)
        }
        return { rows: Math.max(minRows, rows), tiles: tiles }
    }
}
