import QtQuick
import Quickshell
import Quickshell.Io
import qs.models

// System monitor values. Sampling runs only while `sampling` is true (control center open).
Scope {
    id: root

    property bool sampling
    property real cpuPercent
    property var cpuPerCore: []      // list of real, 0..100
    property real cpuTemperatureC
    property real memoryUsedBytes
    property real memoryTotalBytes
    property real diskUsedBytes
    property real diskTotalBytes
    property real netDownBytesPerSec
    property real netUpBytesPerSec
    readonly property real memoryFraction: memoryTotalBytes > 0 ? memoryUsedBytes / memoryTotalBytes : 0
    readonly property real diskFraction: diskTotalBytes > 0 ? diskUsedBytes / diskTotalBytes : 0
    readonly property int cpuSeverity: cpuPercent > 90 ? Enums.Severity.Warn : Enums.Severity.Neutral
    readonly property int memorySeverity: memoryFraction > 0.92 ? Enums.Severity.Critical : memoryFraction > 0.85 ? Enums.Severity.Warn : Enums.Severity.Neutral
    readonly property int diskSeverity: diskFraction > 0.95 ? Enums.Severity.Critical : diskFraction > 0.88 ? Enums.Severity.Warn : Enums.Severity.Neutral
    readonly property int temperatureSeverity: cpuTemperatureC > 95 ? Enums.Severity.Critical : cpuTemperatureC > 85 ? Enums.Severity.Warn : Enums.Severity.Neutral
    property real swapUsedBytes
    property real swapTotalBytes
    property real cpuFrequencyMhz
    property real gpuPercent: -1       // -1 = no sensor found
    property var loadAverage: [0, 0, 0]
    property real uptimeSec
    property var disks: []             // list of { mount, usedBytes, totalBytes, fraction }
    property var topProcesses: []      // list of { name, cpu, memoryBytes }
    property var cpuHistory: []        // last 60 samples, 0..100
    property var memoryHistory: []     // 0..100
    property var netDownHistory: []    // bytes per second
    property var netUpHistory: []
    property int severity: Math.max(cpuSeverity, memorySeverity, diskSeverity, temperatureSeverity)   // Enums.Severity

    property var lastTotals: ({})    // cpu name -> [total, idle]
    property var lastNet: null       // [rx, tx, ms]

    function humanBytes(bytes: real): string {
        const units = ["B", "KB", "MB", "GB", "TB"]
        let v = Math.max(0, bytes)
        let i = 0
        while (v >= 1024 && i < units.length - 1) { v /= 1024; i++ }
        return (v >= 100 || i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i]
    }

    function parse(text: string): void {
        const parts = text.split("@@\n")
        if (parts.length < 10) return
        // CPU
        const cores = []
        const totals = {}
        for (const line of parts[0].split("\n")) {
            if (!line.startsWith("cpu")) continue
            const f = line.trim().split(/\s+/)
            const nums = f.slice(1).map(Number)
            const total = nums.reduce((a, b) => a + b, 0)
            const idle = nums[3] + (nums[4] || 0)
            const prev = lastTotals[f[0]]
            totals[f[0]] = [total, idle]
            if (!prev) continue
            const dt = total - prev[0]
            const pct = dt > 0 ? 100 * (1 - (idle - prev[1]) / dt) : 0
            if (f[0] === "cpu") cpuPercent = Math.max(0, Math.min(100, pct))
            else cores.push(Math.max(0, Math.min(100, pct)))
        }
        lastTotals = totals
        if (cores.length > 0) cpuPerCore = cores
        // Memory
        const mem = {}
        for (const line of parts[1].split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/)
            if (m) mem[m[1]] = Number(m[2]) * 1024
        }
        if (mem.MemTotal) {
            memoryTotalBytes = mem.MemTotal
            memoryUsedBytes = mem.MemTotal - (mem.MemAvailable || mem.MemFree || 0)
        }
        // Network (all interfaces except loopback)
        let rx = 0, tx = 0
        for (const line of parts[2].split("\n")) {
            const m = line.match(/^\s*([^:\s]+):\s*(.*)$/)
            if (!m || m[1] === "lo") continue
            const f = m[2].trim().split(/\s+/).map(Number)
            rx += f[0]; tx += f[8]
        }
        const now = Date.now()
        if (lastNet && now > lastNet[2]) {
            const dt = (now - lastNet[2]) / 1000
            netDownBytesPerSec = Math.max(0, (rx - lastNet[0]) / dt)
            netUpBytesPerSec = Math.max(0, (tx - lastNet[1]) / dt)
        }
        lastNet = [rx, tx, now]
        // Temperature: the hottest CPU sensor
        let temp = 0
        for (const line of parts[3].split("\n")) {
            const f = line.trim().split(" ")
            if (["k10temp", "coretemp", "zenpower", "acpitz"].indexOf(f[0]) >= 0 && Number(f[1]) > 0) temp = Math.max(temp, Number(f[1]) / 1000)
        }
        if (temp > 0) cpuTemperatureC = temp
        // Disks: one entry per distinct filesystem, the root first.
        const seen = {}
        const list = []
        for (const line of parts[4].split("\n")) {
            const m = line.trim().match(/^(\S+)\s+(\d+)\s+(\d+)$/)
            if (!m || Number(m[3]) <= 0) continue
            const key = m[2] + ":" + m[3]
            if (seen[key]) continue
            seen[key] = true
            list.push({ mount: m[1], usedBytes: Number(m[2]), totalBytes: Number(m[3]), fraction: Number(m[2]) / Number(m[3]) })
        }
        if (list.length > 0) {
            disks = list.slice(0, 3)
            const root = list.find(x => x.mount === "/") || list[0]
            diskUsedBytes = root.usedBytes
            diskTotalBytes = root.totalBytes
        }
        // Load, uptime, frequency, GPU
        const la = parts[5].trim().split(/\s+/)
        if (la.length >= 3) loadAverage = [Number(la[0]), Number(la[1]), Number(la[2])]
        const up = (parts[6] || "").trim().split(/\s+/)
        if (up.length >= 1 && Number(up[0]) > 0) uptimeSec = Number(up[0])
        const freqs = (parts[7] || "").trim().split("\n").map(Number).filter(x => x > 0)
        if (freqs.length > 0) cpuFrequencyMhz = freqs.reduce((a, b) => a + b, 0) / freqs.length / 1000
        const gpu = (parts[8] || "").trim()
        gpuPercent = gpu !== "" && !isNaN(Number(gpu)) ? Number(gpu) : -1
        // Swap
        if (mem.SwapTotal !== undefined) {
            swapTotalBytes = mem.SwapTotal
            swapUsedBytes = mem.SwapTotal - (mem.SwapFree || 0)
        }
        // Top processes by CPU; the sampling commands themselves are left out.
        const skip = ["ps", "sh", "cat", "df", "head", "sed", "awk"]
        const procs = []
        for (const line of (parts[9] || "").split("\n")) {
            const m = line.trim().match(/^([\d.]+)\s+(\d+)\s+(.+)$/)
            if (!m || skip.indexOf(m[3]) >= 0) continue
            procs.push({ name: m[3], cpu: Number(m[1]), memoryBytes: Number(m[2]) * 1024 })
            if (procs.length >= 5) break
        }
        topProcesses = procs
        // History for the graphs
        const push = (arr, v) => { const n = arr.concat([v]); return n.length > 60 ? n.slice(n.length - 60) : n }
        cpuHistory = push(cpuHistory, cpuPercent)
        memoryHistory = push(memoryHistory, memoryFraction * 100)
        netDownHistory = push(netDownHistory, netDownBytesPerSec)
        netUpHistory = push(netUpHistory, netUpBytesPerSec)
    }

    function formatUptime(seconds: real): string {
        const d = Math.floor(seconds / 86400)
        const h = Math.floor((seconds % 86400) / 3600)
        const m = Math.floor((seconds % 3600) / 60)
        return (d > 0 ? d + " d " : "") + (h > 0 || d > 0 ? h + " h " : "") + m + " min"
    }

    function sample(): void {
        if (!reader.running) reader.running = true
    }

    Process {
        id: reader
        command: ["sh", "-c", "cat /proc/stat; echo @@; cat /proc/meminfo; echo @@; cat /proc/net/dev; echo @@; for z in /sys/class/hwmon/hwmon*; do echo \"$(cat $z/name 2>/dev/null) $(cat $z/temp1_input 2>/dev/null)\"; done; echo @@; df -B1 --output=target,used,size -x tmpfs -x devtmpfs -x efivarfs -x squashfs -x overlay -x ramfs | tail -n +2; echo @@; cat /proc/loadavg; echo @@; cat /proc/uptime; echo @@; cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null; echo @@; cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1; echo @@; ps -eo pcpu=,rss=,comm= --sort=-pcpu | head -12"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: root.sampling
        triggeredOnStart: true
        onTriggered: root.sample()
    }
}
