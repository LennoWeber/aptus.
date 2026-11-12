pragma ComponentBehavior: Bound
// One tray icon (surfaces/bar.md §5): click activates, right click opens its DBusMenu as an aptus
// menu, middle click is the secondary activation, the wheel scrolls; NeedsAttention shows a 6 px
// warn dot.
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.core
import qs.components

Item {
    id: root

    // The Quickshell SystemTrayItem.
    property var item: null
    // The Hyprland monitor name of this bar (the menu opens there).
    property string monitorName: ""

    readonly property bool hovered: mouse.containsMouse
    // Found in phase 7: the submenu openers of the menu shown last (destroyed at the next open).
    property var _subOpeners: []

    // The item's DBusMenu as an aptus menu below the icon (QsMenuOpener rows → Menu model).
    function openMenu(): void {
        if (!item || !item.hasMenu) return;
        for (const o of _subOpeners) o.destroy();
        _subOpeners = [];
        const p = root.mapToItem(null, 0, height);
        SurfaceManager.openMenu(monitorName, {
            anchorX: p.x, anchorY: p.y + Tokens.s2, model: _rows(opener.children.values), owner: "tray:" + item.id,
            onTriggered: row => root._menuTriggered(row)
        });
    }
    // QsMenuEntry objects → Menu rows ({ id, label, glyph, enabled, separator, checked, entry,
    // submenu }); a submenu's entries come from a nested QsMenuOpener, read when the menu opens.
    function _rows(entries: var): var {
        const rows = [];
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e.isSeparator) { rows.push({ separator: true }); continue; }
            const row = { id: "e" + i, label: String(e.text || "").replace(/_(?=\S)/, ""), enabled: e.enabled, entry: e,
                          checked: e.buttonType !== QsMenuButtonType.None && e.checkState === Qt.Checked };
            if (e.hasChildren) {
                const sub = subOpener.createObject(root, { menu: e }) as QsMenuOpener;
                if (sub) _subOpeners.push(sub);
                row.submenu = sub ? _rows(sub.children.values) : [];
            }
            rows.push(row);
        }
        return rows;
    }
    // A chosen row: its entry's triggered().
    function _menuTriggered(row: var): void {
        if (row && row.entry) row.entry.triggered();
    }

    implicitWidth: Tokens.surfaces.bar.trayIconSize
    implicitHeight: Tokens.surfaces.bar.trayIconSize

    QsMenuOpener {
        id: opener
        menu: root.item ? root.item.menu : null
    }
    Component {
        id: subOpener
        QsMenuOpener {}
    }
    AppIcon {
        anchors.fill: parent
        size: Tokens.surfaces.bar.trayIconSize
        icon: root.item ? String(root.item.icon) : ""
        name: root.item ? root.item.title : ""
    }
    Rectangle {
        visible: !!root.item && root.item.status === Status.NeedsAttention
        width: Tokens.surfaces.bar.trayAttentionDotSize
        height: width
        radius: width / 2
        color: Tokens.warn
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: -width / 3
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -Tokens.s1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: e => {
            if (!root.item) return;
            if (e.button === Qt.RightButton) root.openMenu();
            else if (e.button === Qt.MiddleButton) root.item.secondaryActivate();
            else if (root.item.onlyMenu) root.openMenu();
            else root.item.activate();
        }
        onWheel: w => {
            if (root.item && w.angleDelta.y !== 0) root.item.scroll(w.angleDelta.y, false);
        }
    }
    Tooltip {
        target: root
        text: root.item ? (root.item.tooltipTitle || root.item.title || root.item.id) : ""
        active: root.hovered
    }
}
