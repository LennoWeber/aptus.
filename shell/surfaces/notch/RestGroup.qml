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
    // The right-click menu (notch.md §3) and what its rows do.
    function _menu(x: real, y: real): void {
        const p = root.mapToItem(null, x, y);
        SurfaceManager.openMenu(monitorName, {
            anchorX: p.x, anchorY: p.y, owner: "notch:rest",
            model: [
                { id: "dnd", label: Dnd.on ? "Turn off Do not disturb" : "Turn on Do not disturb", glyph: "do_not_disturb_on" },
                { id: "focus", label: "Start focus", glyph: "center_focus_strong", enabled: !Focus.running },
                { separator: true },
                { id: "calendar", label: "Open calendar", glyph: "calendar_month" }
            ],
            onTriggered: row => root._menuTriggered(row)
        });
    }
    function _menuTriggered(row: var): void {
        const id = row ? row.id : "";
        if (id === "dnd") Dnd.toggle();
        else if (id === "focus") SurfaceManager.open("focusPicker", {}, monitorName);
        else if (id === "calendar") SurfaceManager.open("today", { page: "calendar" }, monitorName);
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
            Behavior on scale { NumberAnimation { duration: Tokens.surfaces.bar.unreadDotMs; easing.type: Easing.OutBack } }
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
