import QtQuick
import qs.models
import qs.theme
import qs.components

// Status icons on the right of the bar.
Item {
    id: group
    // TODO(phase 7, system sections): audio, network, Bluetooth, night light, caffeine and focus join the row with their dropdowns.

    property var audioState
    property var networkState
    property var bluetoothState
    property var batteryState
    property var nightLightState
    property var caffeineState
    property var focusState
    property bool showBatteryPercent: true
    signal itemClicked(int dropdownId, var anchorItem)

    implicitWidth: row.implicitWidth
    implicitHeight: Tokens.barHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter

        BarItem {
            id: audioItem
            dropdownId: Enums.DropdownId.Audio
            onClicked: group.itemClicked(dropdownId, audioItem)

            StatusGlyph {
                anchors.verticalCenter: parent.verticalCenter
                kind: "volume"
                level: group.audioState ? group.audioState.volume : 0
                muted: group.audioState ? group.audioState.muted : false
                color: group.audioState && group.audioState.muted ? Tokens.inkFaint : Tokens.ink
            }
        }

        BarItem {
            id: nightItem
            dropdownId: Enums.DropdownId.NightLight
            onClicked: group.itemClicked(dropdownId, nightItem)

            StatusGlyph {
                anchors.verticalCenter: parent.verticalCenter
                kind: "moon"
                color: group.nightLightState && group.nightLightState.enabled ? Tokens.ink : Tokens.inkFaint
            }
        }

        BarItem {
            id: batteryItem
            visible: group.batteryState ? group.batteryState.present : false
            dropdownId: Enums.DropdownId.Battery
            onClicked: group.itemClicked(dropdownId, batteryItem)

            // A thin battery drawn from rectangles: outline, fill by charge, a small nub.
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 21
                height: 10

                Rectangle {
                    id: body
                    width: 19
                    height: 10
                    radius: 2.5
                    color: "transparent"
                    border.width: 1
                    border.color: group.batteryState && group.batteryState.severity !== Enums.Severity.Neutral ? Tokens.colorFor(group.batteryState.severity) : Tokens.inkSoft

                    Rectangle {
                        x: 2
                        y: 2
                        height: 6
                        width: Math.max(1, 15 * (group.batteryState ? group.batteryState.percent : 0) / 100)
                        radius: 1
                        color: group.batteryState ? Tokens.colorFor(group.batteryState.severity) : Tokens.ink
                        Behavior on width { NumberAnimation { duration: Tokens.durSlow } }
                    }
                }
                Rectangle {
                    x: 19
                    anchors.verticalCenter: body.verticalCenter
                    width: 2
                    height: 4
                    radius: 1
                    color: Tokens.inkSoft
                }
            }

            Label {
                visible: group.showBatteryPercent
                anchors.verticalCenter: parent.verticalCenter
                text: group.batteryState ? Math.round(group.batteryState.percent) + "%" : ""
                role: Enums.TextRole.Bar
                tone: group.batteryState ? group.batteryState.severity : Enums.Severity.Neutral
                color: tone === Enums.Severity.Neutral ? Tokens.ink : Tokens.colorFor(tone)
            }

            // Charging is the one functional signal here: a small bolt in the "ok" colour.
            Canvas {
                visible: group.batteryState ? group.batteryState.charging : false
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 10
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = Tokens.ok
                    ctx.beginPath()
                    ctx.moveTo(4, 0)
                    ctx.lineTo(0, 5.5)
                    ctx.lineTo(2.6, 5.5)
                    ctx.lineTo(1.6, 10)
                    ctx.lineTo(6, 4)
                    ctx.lineTo(3.4, 4)
                    ctx.closePath()
                    ctx.fill()
                }
            }
        }
    }
}
