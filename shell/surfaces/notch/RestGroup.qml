pragma ComponentBehavior: Bound
// The notch at rest (surfaces/notch.md §3): clock HH:mm (rolling minutes, M-34), the date 6 px
// after it, the unread dot 6 px after the date (M-35). Click: Today; right click: the DND / focus /
// calendar menu; hover: the long date as a tooltip.
import QtQuick
import qs.core
import qs.services
import qs.components
import "../../core/js/format.js" as F
import "js/notch.js" as NJ

Item {
    id: root

    // The Hyprland monitor name (Today and the menu open there).
    property string monitorName: ""
    // Found in phase 7: a menu is open on this monitor (no tooltip over it; under the menu's
    // catcher the hover state is not updated).
    // bar.clock.showDate and not a narrow monitor.
    property bool showDate: true
    // Today has unread notifications; one of them is from an allowlisted app (accent dot).
    property bool unread: false
    property bool unreadAllowlisted: false
    // A notch mode took the clock over (M-20): the clock hides while it is open.
    property bool clockTaken: false

    // The clock's rectangle in this item's coordinates (the Notch maps it for clockRect).
    readonly property rect clockRect: Qt.rect(row.x + clock.x, row.y + clock.y, clock.width, clock.height)

    // The texts on screen, refreshed on the minute boundary (one aligned timer, 04 §8).
    property string _time: ""
    property string _date: ""
    property string _longDate: ""

    // Refresh the texts and arm the timer for the next minute boundary.
    function _refresh(): void {
        const now = new Date();
        _time = F.time(now);
        _date = F.dateShort(now);
        _longDate = NJ.longDate(now);
        minute.interval = (60 - now.getSeconds()) * 1000 - now.getMilliseconds() + 20;
        minute.restart();
    }
    // The right-click menu (notch.md §3): Do not disturb ▸ (1 hour, until tomorrow 08:00 as in
    // deck.md, until I turn it off; Turn off while on), Start focus ▸ (25, 50, 90 min), Open
    // calendar settings; and what its rows do.
    function _menu(x: real, y: real): void {
        const p = root.mapToItem(null, x, y);
        const dnd = [{ id: "dnd:1h", label: "For 1 hour" }, { id: "dnd:tomorrow", label: "Until tomorrow 08:00" },
                     { id: "dnd:on", label: "Until I turn it off" }];
        if (Dnd.on) dnd.push({ separator: true }, { id: "dnd:off", label: "Turn off" });
        SurfaceManager.openMenu(monitorName, {
            anchorX: p.x, anchorY: p.y, owner: "notch:rest",
            model: [
                { id: "dnd", label: "Do not disturb", glyph: "do_not_disturb_on", submenu: dnd },
                { id: "focus", label: "Start focus", glyph: "center_focus_strong", enabled: !Focus.running,
                  submenu: [25, 50, 90].map(n => ({ id: "focus:" + n, label: n + " min" })) },
                { separator: true },
                { id: "calendar", label: "Open calendar settings", glyph: "calendar_month" }
            ],
            onTriggered: row => root._menuTriggered(row)
        });
    }
    function _menuTriggered(row: var): void {
        const id = String(row && row.id || "");
        if (id === "dnd:1h") Dnd.forSeconds(3600);
        else if (id === "dnd:tomorrow") Dnd.untilTime("08:00");
        else if (id === "dnd:on") Dnd.turnOn();
        else if (id === "dnd:off") Dnd.turnOff();
        else if (id.indexOf("focus:") === 0) Focus.start(Number(id.substring(6)), "");
        else if (id === "calendar") SurfaceManager.open("settings", { page: "today" }, monitorName);   // "Today & calendar"
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Tokens.barHeight
    Component.onCompleted: _refresh()

    Timer { id: minute; onTriggered: root._refresh() }
    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.surfaces.notch.clockDateGap
        RollingDigits {
            id: clock
            anchors.verticalCenter: parent.verticalCenter
            role: "clock"
            text: root._time
            opacity: root.clockTaken ? 0 : 1
            Behavior on opacity { StandardAnimation { duration: Motion.ms("fade", root.clockTaken) } }
        }
        Label {
            visible: root.showDate
            anchors.verticalCenter: parent.verticalCenter
            type: "micro"
            ink: "meta"
            text: root._date
        }
        Rectangle {
            id: dot
            anchors.verticalCenter: parent.verticalCenter
            width: Tokens.surfaces.notch.unreadDotSize
            height: width
            radius: width / 2
            color: root.unreadAllowlisted ? Tokens.accent : Tokens.inkSec
            scale: root.unread ? 1 : 0
            visible: scale > 0
            Behavior on scale { enabled: !Motion.reduced; SnappySpring {} }       // M-35
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton) root._menu(m.x, m.y);
            else SurfaceManager.toggle("today", {}, root.monitorName);
        }
    }
    Tooltip {
        target: root
        text: root._longDate
        active: mouse.containsMouse
    }
}
