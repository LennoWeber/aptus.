pragma ComponentBehavior: Bound
// The tray (surfaces/bar.md §5): status-notifier items, 16 px, 6 apart, at most bar.tray.max
// visible, the rest behind an `expand_more` overflow menu; shown on the primary monitor only
// unless bar.tray.monitor is `all`.
import QtQuick
import Quickshell.Services.SystemTray
import qs.core
import qs.components
import "js/bar.js" as B

Item {
    id: root

    // The Hyprland monitor name of this bar.
    property string monitorName: ""
    // Found in phase 7: a menu is open on this monitor (no tooltip over it; under the menu's
    // catcher the hover state is not updated).
    // bar.tray.max (2 on a narrow monitor), bar.tray.hidden, bar.tray.order.
    property int maxItems: 0
    property var hiddenIds: []
    property var order: []
    // The tray shows on this monitor (bar.tray.monitor).
    property bool shown: true

    // The items in the bar and those behind the overflow button (bar.js trayLayout).
    readonly property var _layout: B.trayLayout(SystemTray.items.values, maxItems, hiddenIds, order)
    // The items in the bar and those behind the overflow button (bar.js trayLayout).
    readonly property var shownItems: _layout.shown
    readonly property var overflowItems: _layout.overflow

    // The overflow menu (icon + title rows) below the `expand_more` button.
    function _overflowMenu(x: real, y: real): void {
        const p = overflowButton.mapToItem(null, x, y);
        SurfaceManager.openMenu(monitorName, {
            anchorX: p.x, anchorY: p.y, owner: "tray:overflow",
            model: overflowItems.map(i => ({ id: i.id, label: i.tooltipTitle || i.title || i.id, icon: String(i.icon || ""), item: i })),
            onTriggered: row => root._overflowTriggered(row)
        });
    }
    // An overflow row: activate that item.
    function _overflowTriggered(row: var): void {
        if (row && row.item) row.item.activate();
    }

    visible: shown && (shownItems.length > 0 || overflowItems.length > 0)
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: Tokens.surfaces.bar.trayIconSize

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.surfaces.bar.trayGap
        layoutDirection: Qt.RightToLeft
        Repeater {
            model: root.shownItems
            delegate: TrayItem {
                required property var modelData
                item: modelData
                monitorName: root.monitorName
            }
        }
        Item {
            id: overflowButton
            visible: root.overflowItems.length > 0
            width: Tokens.surfaces.bar.trayIconSize
            height: width
            Glyph {
                anchors.centerIn: parent
                name: "expand_more"
                size: Tokens.surfaces.bar.trayIconSize
                colour: ComponentShared.ink("sec")
            }
            MouseArea {
                id: overflowMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root._overflowMenu(0, overflowButton.height + Tokens.s2)
            }
            Tooltip {
                target: overflowButton
                text: root.overflowItems.length + " more"
                active: overflowMouse.containsMouse
            }
        }
    }
}
