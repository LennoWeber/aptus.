import QtQuick
import qs.theme

// Small line symbols for the status area, drawn so no icon font is needed (16 px grid, 1.5 px stroke).
Canvas {
    id: glyph

    property string kind: "volume"   // wifi | bluetooth | volume | mic | moon | play | pause | next | prev | cup | back | sliders | rotate | tablet | lock | logout | restart | power | focus | shield | hotspot | capture | sun | cloud | partly | rain | snow | storm | fog
    property real level: 1           // volume: 0..1, drives the number of waves
    property bool muted
    property color color: Tokens.ink

    implicitWidth: 16
    implicitHeight: 16
    onColorChanged: requestPaint()
    onKindChanged: requestPaint()
    onLevelChanged: requestPaint()
    onMutedChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.scale(width / 16, height / 16)
        ctx.strokeStyle = color
        ctx.fillStyle = color
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        if (kind === "volume") {
            ctx.beginPath()
            ctx.moveTo(2, 6)
            ctx.lineTo(5, 6)
            ctx.lineTo(8.5, 3)
            ctx.lineTo(8.5, 13)
            ctx.lineTo(5, 10)
            ctx.lineTo(2, 10)
            ctx.closePath()
            ctx.stroke()
            if (muted) {
                ctx.beginPath()
                ctx.moveTo(11, 6)
                ctx.lineTo(15, 10)
                ctx.moveTo(15, 6)
                ctx.lineTo(11, 10)
                ctx.stroke()
            } else {
                if (level > 0.01) { ctx.beginPath(); ctx.arc(8.5, 8, 3.2, -0.9, 0.9); ctx.stroke() }
                if (level > 0.5) { ctx.beginPath(); ctx.arc(8.5, 8, 6, -0.9, 0.9); ctx.stroke() }
            }
        } else if (kind === "mic") {
            ctx.beginPath()
            ctx.roundedRect(6, 1.5, 4, 8, 2, 2)
            ctx.moveTo(3.5, 7.5)
            ctx.arc(8, 7.5, 4.5, Math.PI, 0, true)
            ctx.moveTo(8, 12)
            ctx.lineTo(8, 14.5)
            if (muted) { ctx.moveTo(2.5, 2.5); ctx.lineTo(13.5, 13.5) }
            ctx.stroke()
        } else if (kind === "play") {
            ctx.beginPath()
            ctx.moveTo(4.5, 2.5); ctx.lineTo(13, 8); ctx.lineTo(4.5, 13.5); ctx.closePath()
            ctx.fill()
        } else if (kind === "pause") {
            ctx.fillRect(3.5, 2.5, 3.2, 11)
            ctx.fillRect(9.3, 2.5, 3.2, 11)
        } else if (kind === "next" || kind === "prev") {
            if (kind === "prev") { ctx.translate(16, 0); ctx.scale(-1, 1) }
            ctx.beginPath()
            ctx.moveTo(3, 3); ctx.lineTo(10.5, 8); ctx.lineTo(3, 13); ctx.closePath()
            ctx.fill()
            ctx.fillRect(11.5, 3, 2, 10)
        } else if (kind === "cup") {
            ctx.beginPath()
            ctx.moveTo(2.5, 6.5); ctx.lineTo(2.5, 11); ctx.arcTo(2.5, 14, 5.5, 14, 3); ctx.lineTo(8.5, 14); ctx.arcTo(11.5, 14, 11.5, 11, 3); ctx.lineTo(11.5, 6.5); ctx.closePath()
            ctx.moveTo(11.5, 8); ctx.lineTo(13, 8); ctx.arcTo(14.5, 8, 14.5, 9.5, 1.5); ctx.arcTo(14.5, 11, 13, 11, 1.5); ctx.lineTo(11.5, 11)
            ctx.moveTo(5, 2); ctx.lineTo(5, 4.2); ctx.moveTo(9, 2); ctx.lineTo(9, 4.2)
            ctx.stroke()
        } else if (kind === "sliders") {
            ctx.beginPath()
            for (const l of [[3.2, 10.5], [8, 5], [12.8, 9.5]]) {
                ctx.moveTo(1.8, l[0]); ctx.lineTo(14.2, l[0])
                ctx.moveTo(l[1] + 1.7, l[0]); ctx.arc(l[1], l[0], 1.7, 0, 2 * Math.PI)
            }
            ctx.stroke()
        } else if (kind === "focus") {
            ctx.beginPath(); ctx.arc(8, 8, 6, 0, 2 * Math.PI); ctx.stroke()
            ctx.beginPath(); ctx.arc(8, 8, 2.2, 0, 2 * Math.PI); ctx.fill()
        } else if (kind === "shield") {
            ctx.beginPath()
            ctx.moveTo(8, 1.8); ctx.lineTo(13.2, 3.8); ctx.lineTo(13.2, 8)
            ctx.bezierCurveTo(13.2, 11.2, 11, 13.2, 8, 14.2)
            ctx.bezierCurveTo(5, 13.2, 2.8, 11.2, 2.8, 8)
            ctx.lineTo(2.8, 3.8); ctx.closePath(); ctx.stroke()
        } else if (kind === "hotspot") {
            ctx.beginPath(); ctx.arc(8, 11, 3.6, -2.62, -0.52); ctx.stroke()
            ctx.beginPath(); ctx.arc(8, 11, 7, -2.62, -0.52); ctx.stroke()
            ctx.beginPath(); ctx.arc(8, 11, 1.4, 0, 2 * Math.PI); ctx.fill()
        } else if (kind === "capture") {
            ctx.beginPath()
            ctx.moveTo(2, 5.5); ctx.lineTo(2, 2); ctx.lineTo(5.5, 2)
            ctx.moveTo(10.5, 2); ctx.lineTo(14, 2); ctx.lineTo(14, 5.5)
            ctx.moveTo(14, 10.5); ctx.lineTo(14, 14); ctx.lineTo(10.5, 14)
            ctx.moveTo(5.5, 14); ctx.lineTo(2, 14); ctx.lineTo(2, 10.5)
            ctx.stroke()
            ctx.beginPath(); ctx.arc(8, 8, 1.8, 0, 2 * Math.PI); ctx.fill()
        } else if (kind === "sun" || kind === "partly" || kind === "cloud" || kind === "rain" || kind === "snow" || kind === "storm" || kind === "fog") {
            // Cloud outline, drawn shifted by dy and scaled by s around the centre.
            const cloud = (dy, s) => {
                ctx.save()
                ctx.translate(8, 8 + dy); ctx.scale(s, s); ctx.translate(-8, -8)
                ctx.beginPath()
                ctx.moveTo(4.5, 12.5)
                ctx.arc(4.5, 9.7, 2.8, Math.PI * 0.5, Math.PI * 1.5)
                ctx.arc(8, 7, 3.3, Math.PI * 1.15, Math.PI * 1.9)
                ctx.arc(11.5, 9.7, 2.8, Math.PI * 1.5, Math.PI * 0.5)
                ctx.closePath(); ctx.stroke()
                ctx.restore()
            }
            const sunAt = (cx, cy, r, rays) => {
                ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke()
                for (let i = 0; i < rays; i++) {
                    const a = i * 2 * Math.PI / rays
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(a) * (r + 1.8), cy + Math.sin(a) * (r + 1.8))
                    ctx.lineTo(cx + Math.cos(a) * (r + 3.2), cy + Math.sin(a) * (r + 3.2))
                    ctx.stroke()
                }
            }
            if (kind === "sun") sunAt(8, 8, 3, 8)
            else if (kind === "cloud") cloud(0, 1)
            else if (kind === "partly") { sunAt(5.2, 5.2, 2, 6); cloud(2.2, 0.8) }
            else if (kind === "rain") {
                cloud(-2.5, 0.85)
                ctx.beginPath()
                ctx.moveTo(5, 11.5); ctx.lineTo(4, 14.5); ctx.moveTo(8, 11.5); ctx.lineTo(7, 14.5); ctx.moveTo(11, 11.5); ctx.lineTo(10, 14.5)
                ctx.stroke()
            } else if (kind === "snow") {
                cloud(-2.5, 0.85)
                for (const x of [5, 8, 11]) { ctx.beginPath(); ctx.arc(x, 13.2, 0.9, 0, 2 * Math.PI); ctx.fill() }
            } else if (kind === "storm") {
                cloud(-2.5, 0.85)
                ctx.beginPath()
                ctx.moveTo(8.8, 10.5); ctx.lineTo(6.6, 13); ctx.lineTo(9, 13); ctx.lineTo(7.2, 15.5)
                ctx.stroke()
            } else {
                ctx.beginPath()
                ctx.moveTo(2, 5.5); ctx.lineTo(14, 5.5); ctx.moveTo(3.5, 8.5); ctx.lineTo(12.5, 8.5); ctx.moveTo(2, 11.5); ctx.lineTo(14, 11.5)
                ctx.stroke()
            }
        } else if (kind === "wifi") {
            // Three arcs and a dot; arcs above the signal level are faint.
            const arcs = [[3.4, 0.25], [6.6, 0.55], [9.8, 0.85]]
            for (const a of arcs) {
                ctx.globalAlpha = level >= a[1] ? 1 : 0.28
                ctx.beginPath(); ctx.arc(8, 13, a[0], -2.36, -0.78); ctx.stroke()
            }
            ctx.globalAlpha = 1
            ctx.beginPath(); ctx.arc(8, 13, 1.1, 0, 2 * Math.PI); ctx.fill()
            if (muted) { ctx.beginPath(); ctx.moveTo(2.5, 2.5); ctx.lineTo(13.5, 13.5); ctx.stroke() }
        } else if (kind === "bluetooth") {
            ctx.beginPath()
            ctx.moveTo(4, 5); ctx.lineTo(12, 11.5); ctx.lineTo(8, 14.8); ctx.lineTo(8, 1.2); ctx.lineTo(12, 4.5); ctx.lineTo(4, 11)
            ctx.stroke()
        } else if (kind === "back") {
            ctx.beginPath()
            ctx.moveTo(9.5, 3); ctx.lineTo(4.5, 8); ctx.lineTo(9.5, 13)
            ctx.stroke()
        } else if (kind === "rotate") {
            ctx.strokeRect(5, 5, 6, 6)
            ctx.beginPath()
            ctx.arc(8, 8, 6.2, Math.PI * 1.15, Math.PI * 1.85, false)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(12.6, 2.6); ctx.lineTo(13.4, 5.2); ctx.lineTo(10.6, 5)
            ctx.stroke()
        } else if (kind === "tablet") {
            ctx.strokeRect(3, 1.5, 10, 13)
            ctx.beginPath()
            ctx.moveTo(7, 12.5); ctx.lineTo(9, 12.5)
            ctx.stroke()
        } else if (kind === "lock") {
            ctx.strokeRect(3.5, 7, 9, 6.5)
            ctx.beginPath()
            ctx.moveTo(5.5, 7); ctx.lineTo(5.5, 5); ctx.arc(8, 5, 2.5, Math.PI, 0, false); ctx.lineTo(10.5, 7)
            ctx.stroke()
        } else if (kind === "logout") {
            ctx.beginPath()
            ctx.moveTo(7, 2.5); ctx.lineTo(3, 2.5); ctx.lineTo(3, 13.5); ctx.lineTo(7, 13.5)
            ctx.moveTo(6, 8); ctx.lineTo(13, 8)
            ctx.moveTo(10.5, 5.5); ctx.lineTo(13, 8); ctx.lineTo(10.5, 10.5)
            ctx.stroke()
        } else if (kind === "restart") {
            ctx.beginPath()
            ctx.arc(8, 8, 5, -Math.PI * 0.35, Math.PI * 1.55, false)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(10.5, 1.5); ctx.lineTo(12.6, 4.2); ctx.lineTo(9.4, 5)
            ctx.stroke()
        } else if (kind === "power") {
            ctx.beginPath()
            ctx.arc(8, 8.5, 5, -Math.PI * 0.32, Math.PI * 1.32, false)
            ctx.moveTo(8, 2); ctx.lineTo(8, 8)
            ctx.stroke()
        } else if (kind === "moon") {
            // A crescent from two arcs, drawn on a 24 px grid and scaled down.
            const rad = d => d * Math.PI / 180
            ctx.scale(16 / 24, 16 / 24)
            ctx.lineWidth = 1.5 * 24 / 16
            ctx.beginPath()
            ctx.arc(12, 12, 9, rad(5), rad(265), false)
            ctx.arc(16.84, 7.15, 7, rad(216.4), rad(53.6), true)
            ctx.closePath()
            ctx.stroke()
        }
    }
}
