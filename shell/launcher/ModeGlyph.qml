import QtQuick
import qs.models
import qs.theme

// A small line symbol for one launcher mode (16 px grid, 1.5 px stroke), drawn so no icon font is needed.
Canvas {
    id: glyph

    property int mode: Enums.LauncherMode.Apps  // Enums.LauncherMode
    property color color: Tokens.ink

    implicitWidth: 16
    implicitHeight: 16
    onColorChanged: requestPaint()
    onModeChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.scale(width / 16, height / 16)
        ctx.strokeStyle = color
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.beginPath()
        switch (mode) {
        case Enums.LauncherMode.Apps:
            for (const p of [[2.2, 2.2], [9.2, 2.2], [2.2, 9.2], [9.2, 9.2]]) ctx.roundedRect(p[0], p[1], 4.6, 4.6, 1.4, 1.4)
            break
        case Enums.LauncherMode.Web:
            ctx.arc(8, 8, 6.2, 0, 2 * Math.PI)
            ctx.moveTo(1.8, 8)
            ctx.lineTo(14.2, 8)
            ctx.save()
            ctx.translate(8, 8)
            ctx.scale(0.42, 1)
            ctx.moveTo(6.2, 0)
            ctx.arc(0, 0, 6.2, 0, 2 * Math.PI)
            ctx.restore()
            break
        case Enums.LauncherMode.Settings:
            for (const l of [[3.2, 10.5], [8, 5], [12.8, 9.5]]) {
                ctx.moveTo(1.8, l[0])
                ctx.lineTo(14.2, l[0])
                ctx.moveTo(l[1] + 1.7, l[0])
                ctx.arc(l[1], l[0], 1.7, 0, 2 * Math.PI)
            }
            break
        case Enums.LauncherMode.Ai:
            ctx.moveTo(8, 1.4)
            ctx.lineTo(9.7, 6.3)
            ctx.lineTo(14.6, 8)
            ctx.lineTo(9.7, 9.7)
            ctx.lineTo(8, 14.6)
            ctx.lineTo(6.3, 9.7)
            ctx.lineTo(1.4, 8)
            ctx.lineTo(6.3, 6.3)
            ctx.closePath()
            break
        case Enums.LauncherMode.Clipboard:
            ctx.roundedRect(3, 3.2, 10, 11.4, 1.8, 1.8)
            ctx.roundedRect(5.6, 1.4, 4.8, 3.4, 1.2, 1.2)
            break
        }
        ctx.stroke()
    }
}
