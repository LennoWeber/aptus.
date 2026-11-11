pragma ComponentBehavior: Bound
// The status cluster (surfaces/bar.md §6): one pill, `raised` on hover only, with the battery,
// volume, Bluetooth, network, DND and privacy items right to left; items open and close with M-04.
import QtQuick
import qs.core
import qs.services
import qs.components
import "js/bar.js" as B

Item {
    id: root

    // The Hyprland monitor name of this bar (the Deck opens there).
    property string monitorName: ""
    // Quiet bar (M-31b): only the items that keep (privacy, recording, battery ≤ 30 %) stay.
    property bool quiet: false

    // The status items now (bar.js statusItems), right to left.
    readonly property var items: B.statusItems({
        battery: Power.hasBattery ? { hasBattery: true, percentage: Power.percentage, charging: Power.charging,
                                      timeToEmpty: Power.timeToEmpty, timeToFull: Power.timeToFull, profile: Power.profile } : null,
        volume: Audio.ready ? { level: Audio.volume, muted: Audio.muted, device: Audio.sinkName } : null,
        bluetooth: { available: Bt.available, enabled: Bt.enabled, connected: Bt.connected },
        network: Network.available ? { kind: Network.kind, online: Network.online, ssid: Network.ssid,
                                       strength: Network.strength, vpn: Network.vpnName } : null,
        dnd: { on: Dnd.on, until: Dnd.until ? Qt.formatTime(Dnd.until, "HH:mm") : "", focus: Focus.running },
        privacy: { mic: Privacy.mic, camera: Privacy.camera, screencast: Privacy.screencast },
        // (the schema defaults until Config has loaded: bar.js checks the enums)
        settings: { batteryPercent: Config.get("bar.battery.percent") || "auto", bluetooth: Config.get("bar.bluetooth") || "connected" }
    }, quiet, Tokens.surfaces.bar)
    // id → item record of `items`.
    readonly property var _byId: {
        const m = {};
        for (const i of items) m[i.id] = i;
        return m;
    }
    // Items that left but still close (M-04), by id: the record they showed last.
    property var _leaving: ({})
    onItemsChanged: {
        const l = Object.assign({}, _leaving);
        for (const i of items) l[i.id] = i;
        _leaving = l;
    }

    // The inputs of bar.md §6: click opens the Deck at the item's section ("" = the top), the
    // wheel on volume / battery steps volume / brightness, middle on volume mutes, right on
    // network / Bluetooth toggles Wi-Fi / Bluetooth.
    function _open(section: string): void {
        SurfaceManager.open("deck", section === "" ? {} : B.deckArgs(section, !!Config.get("deck.openPages")), monitorName);
    }
    function _wheel(id: string, direction: int): void {
        if (id === "volume") Audio.stepVolume(direction, false);
        else if (id === "battery") Brightness.step(direction, false);
    }
    function _middle(id: string): void {
        if (id === "volume") Audio.toggleMute();
    }
    function _right(id: string): void {
        if (id === "network") Network.setWifiEnabled(!Network.wifiEnabled);
        else if (id === "bluetooth") Bt.setEnabled(!Bt.enabled);
    }

    implicitWidth: row.implicitWidth + 2 * Tokens.s4
    implicitHeight: Tokens.surfaces.bar.statusPillHeight
    visible: implicitWidth > 2 * Tokens.s4

    Rectangle {
        anchors.fill: parent
        radius: Tokens.surfaces.bar.statusPillRadius
        color: pad.containsMouse ? Tokens.raised : Tokens.alpha(Tokens.raised, 0)
        Behavior on color { StandardColorAnimation { duration: Motion.ms("hover", false) } }
    }
    MouseArea {
        id: pad
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root._open("")
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0
        layoutDirection: Qt.RightToLeft
        Repeater {
            model: B.STATUS_ORDER
            delegate: StatusItem {
                id: si
                required property string modelData
                readonly property bool _live: root._byId[modelData] !== undefined
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                item: root._byId[modelData] || root._leaving[modelData] || ({})
                shown: _live
                // the gap belongs to the item so a closed item takes no space
                width: implicitWidth > 0 ? implicitWidth + Tokens.surfaces.bar.statusIconGap * _open : 0
                onClicked: root._open(item.section || "")
                onWheelStep: d => root._wheel(modelData, d)
                onMiddleClicked: root._middle(modelData)
                onRightClicked: root._right(modelData)
                // the battery turning critical while discharging → its nudge (M-36)
                readonly property bool _crit: modelData === "battery" && item.ink === "crit" && !Power.charging
                on_CritChanged: if (_crit) nudge()
            }
        }
    }
}
