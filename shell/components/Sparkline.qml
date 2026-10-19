import QtQuick
import qs.theme

// Small history graph: a thin line with a soft fill, newest value on the right.
Canvas {
    id: spark

    property var values: []       // list of real, oldest first
    property real maximum: 0      // 0 = scale to the largest value
    property color lineColor: Tokens.ink
    property color fillColor: Tokens.surfaceAlt

    implicitWidth: 200
    implicitHeight: 48
    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const v = values || []
        // Baseline.
        ctx.strokeStyle = Tokens.line
        ctx.lineWidth = 1
        ctx.beginPath(); ctx.moveTo(0, height - 0.5); ctx.lineTo(width, height - 0.5); ctx.stroke()
        if (v.length < 2) return
        let top = maximum > 0 ? maximum : Math.max.apply(null, v)
        if (!(top > 0)) top = 1
        const step = width / 59   // always 60 slots, so the graph fills from the right
        const x0 = width - (v.length - 1) * step
        const y = val => height - 2 - Math.min(1, Math.max(0, val / top)) * (height - 4)
        ctx.beginPath()
        ctx.moveTo(x0, height)
        for (let i = 0; i < v.length; i++) ctx.lineTo(x0 + i * step, y(v[i]))
        ctx.lineTo(x0 + (v.length - 1) * step, height)
        ctx.closePath()
        ctx.fillStyle = fillColor
        ctx.fill()
        ctx.beginPath()
        for (let i = 0; i < v.length; i++) {
            if (i === 0) ctx.moveTo(x0, y(v[0]))
            else ctx.lineTo(x0 + i * step, y(v[i]))
        }
        ctx.strokeStyle = lineColor
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.stroke()
    }
}
