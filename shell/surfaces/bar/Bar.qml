// The bar: the frame's top edge with workspaces, active window, tray and status cluster (surfaces/bar.md).
// Owner: S1 (static skeleton), S3 (contents).
import QtQuick
import qs.core
import qs.services
import "js/bar.js" as B
import "../../services/js/hypr.js" as H

Item {
    id: root

    property MonitorState monitor
    property real introProgress: 1
    // The notch's rest width; the left and right zones stay clear of it.
    property real notchWidth: 0
    // M-14: the workspace pills in monitor coordinates, [{ workspace, x, y, width, height }],
    // for the overview's shared-element morph.
    readonly property var pillRects: strip.pillRects.map(r => {
        const p = strip.mapToItem(null, r.x, r.y);
        return { workspace: r.workspace, x: p.x, y: p.y, width: r.width, height: r.height };
    })
    // How far the frame is slid out under a fullscreen window (Frame.hide, M-31); the bar follows.
    property real hide: 0

    // Quiet bar (M-31b, Focus.quietBar): title, tray, date and non-critical status collapse.
    // TODO(S8): the hover reveal, together with M-31b's fade and collapse (`small`) of the title,
    // the tray and the date (both ways: the reveal plays it back). Until S8 sets quietBar they
    // only switch; the status items already leave with M-04.
    readonly property bool quiet: Focus.quietBar
    // A monitor narrower than surfaces.bar.narrowMonitorWidth (bar.md §9): date hidden, title
    // ≤ 240, tray ≤ 2.
    readonly property bool narrow: width > 0 && width < Tokens.surfaces.bar.narrowMonitorWidth

    height: Tokens.barHeight
    // M-01 slides the bar down from above the screen; M-31 slides it up again.
    y: -Tokens.barHeight * (1 - introProgress) - Tokens.barHeight * hide
    opacity: 1 - hide

    // Content starts padBar from the frame edge (03 §7); the centre stays clear for the notch.
    readonly property real _inset: Tokens.frameEdge + Tokens.padBar
    // Width of each side zone (left, right) around the notch.
    readonly property real _sideWidth: Math.max(0, (width - notchWidth) / 2 - _inset - Tokens.gapBarZone)

    // Found by the probe (phase 5):
    // This monitor's name, its Hyprland record and its active workspace record.
    readonly property string _name: monitor ? monitor.name : ""
    // This monitor's Hyprland record and its active workspace record.
    readonly property var _hm: Hypr.monitors.find(m => m.name === _name) || null
    readonly property var _activeWs: _hm ? Hypr.workspaces.find(w => w.id === _hm.activeWorkspace) || null : null
    // The primary monitor (10-settings: the external one when connected, else eDP-1).
    readonly property bool _primary: {
        const names = Hypr.monitors.map(m => m.name);
        const ext = names.find(n => n !== H.INTERNAL);
        return _name === (ext !== undefined ? ext : H.INTERNAL);
    }

    // Zones: workspaces and window title left, tray and status right.
    Row {
        id: leftZone
        x: root._inset
        width: root._sideWidth
        height: parent.height
        spacing: Tokens.gapBarItem
        layoutDirection: Qt.LeftToRight
        WorkspaceStrip {
            id: strip
            anchors.verticalCenter: parent.verticalCenter
            monitorName: root._name
            strip: Hypr.stripFor(root._name)
            maxWidth: root.width * Tokens.surfaces.bar.stripMaxWidthFraction
            showIcons: !!Config.get("bar.workspaces.icons")
            introProgress: root.introProgress
        }
        ActiveWindow {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.quiet && !!Config.get("bar.title.show")
            monitorName: root._name
            window: {
                const w = Hypr.activeWindow;
                return w && root._hm && w.monitor === root._name && w.workspace === root._hm.activeWorkspace ? w : null;
            }
            fallback: root._activeWs ? root._activeWs.name : ""
            maxWidth: B.titleWidth(root._sideWidth - strip.width - Tokens.gapBarItem, root.narrow, Tokens.surfaces.bar)
        }
    }
    Row {
        id: rightZone
        x: root.width - root._inset - width
        width: root._sideWidth
        height: parent.height
        spacing: Tokens.gapBarItem
        layoutDirection: Qt.RightToLeft
        StatusCluster {
            anchors.verticalCenter: parent.verticalCenter
            monitorName: root._name
            quiet: root.quiet
        }
        Tray {
            anchors.verticalCenter: parent.verticalCenter
            monitorName: root._name
            maxItems: root.narrow ? Math.min(Tokens.surfaces.bar.narrowTrayMax, Config.get("bar.tray.max")) : Config.get("bar.tray.max")
            hiddenIds: Config.get("bar.tray.hidden") || []
            order: Config.get("bar.tray.order") || []
            shown: !root.quiet && (Config.get("bar.tray.monitor") === "all" || root._primary)
        }
    }
}
