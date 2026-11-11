pragma ComponentBehavior: Bound
// The workspace strip (surfaces/bar.md §3): the overview button, one pill per workspace of this
// monitor, the accent capsule that slides between pills (M-02) and the scratch pill.
import QtQuick
import qs.core
import qs.services
import qs.components
import "js/bar.js" as B
import "../../services/js/hypr.js" as H

Item {
    id: root

    // The Hyprland monitor name of this bar.
    property string monitorName: ""
    // Found in phase 7: a menu is open on this monitor (no tooltip over it; under the menu's
    // catcher the hover state is not updated).
    readonly property bool _menuOpen: { const m = SurfaceManager.monitorState(monitorName); return !!m && m.menu !== null; }
    // This monitor's strip (hypr.js strip record: pills and scratch).
    property var strip: ({ pills: [], scratch: null })
    // bar.workspaces.icons.
    property bool showIcons: true
    // The most the strip may take (bar.md §3: 40 % of the bar's width).
    property real maxWidth: 0
    // 0 → 1 during the session intro (M-01: pills stagger in 30 ms apart).
    property real introProgress: 1

    // Icon collapse (bar.js collapseLevel): 0 icons on every pill, 1 numbers on the inactive
    // pills, 2 numbers only.
    readonly property int collapse: {
        let full = overviewButton.width + Tokens.surfaces.bar.pillGap, inactive = full, none = full;
        for (let i = 0; i < pills.count; i++) {
            const p = pills.itemAt(i) as WorkspacePill;
            if (!p) continue;
            const gap = Tokens.surfaces.bar.pillGap;
            full += p.fullWidth + gap;
            inactive += (p.workspace.active ? p.fullWidth : p.numberWidth) + gap;
            none += p.numberWidth + gap;
        }
        return B.collapseLevel(full, inactive, none, maxWidth);
    }
    // M-14: the pills in strip coordinates, [{ workspace, x, y, width, height }] (Bar.pillRects
    // maps them to monitor coordinates).
    readonly property var pillRects: {
        const out = [];
        void pillRow.width;
        for (let i = 0; i < pills.count; i++) {
            const p = pills.itemAt(i) as WorkspacePill;
            if (p) out.push({ workspace: p.workspace.id, x: pillRow.x + p.x, y: pillRow.y + p.y, width: p.width, height: p.height });
        }
        return out;
    }

    // The accent capsule's edges in strip coordinates (M-02: the leading edge leads, the trailing
    // edge follows 40 ms later).
    property real _capsuleLeft: 0
    property real _capsuleRight: 0
    // The active pill's index a moment ago (which edge leads).
    property int _lastActive: -1
    // The trailing edge's target (set when trailTimer fires).
    property real _trailTo: 0
    property bool _trailIsLeft: false

    // A pill's actions (bar.md §3): go there; move the focused window there (stay); its menu at a
    // point in strip coordinates; the wheel steps to the previous / next used workspace.
    function _go(record: var): void { Hypr.focusWorkspace(String(record.id)); }
    function _moveHere(record: var): void { Hypr.moveToWorkspace("", String(record.id)); }
    function _menu(record: var, x: real, y: real): void {
        const p = root.mapToItem(null, x, y);
        SurfaceManager.openMenu(monitorName, {
            anchorX: p.x, anchorY: p.y, owner: "bar:pill",
            model: B.pillMenu(record, Hypr.monitors.map(m => m.name), monitorName),
            onTriggered: row => root._menuTriggered(record, row)
        });
    }
    // The pill menu's rows (bar.js pillMenu): Rename… opens the overview with the workspace for
    // its F2 rename (overview.md §5, S6: args { workspace, rename: true }; the bar never takes the
    // keyboard), Move focused window here, Move workspace to ▸, Close all windows… (confirmed).
    function _menuTriggered(record: var, row: var): void {
        const id = String(row && row.id || "");
        if (id === "rename") SurfaceManager.open("overview", { workspace: record.id, rename: true }, monitorName);
        else if (id === "movehere") _moveHere(record);
        else if (id === "closeall") Hypr.closeWorkspaceWindows(record.id);
        else if (id.indexOf("mon:") === 0) Hypr.moveWorkspaceToMonitor(record.id, id.substring(4));
    }
    function _wheel(direction: int): void {
        const cur = strip.pills.find(p => p.active);
        const next = H.neighbour(strip, cur ? cur.id : 0, direction);
        if (cur && next !== cur.id) Hypr.focusWorkspace(String(next));
    }
    // Move the capsule to the active pill (M-02: the leading edge first).
    function _placeCapsule(): void {
        let idx = -1;
        for (let i = 0; i < strip.pills.length; i++) if (strip.pills[i].active) idx = i;
        const p = idx >= 0 ? pills.itemAt(idx) as WorkspacePill : null;
        if (!p) return;
        const l = pillRow.x + p.x, r = l + p.width;
        if (_lastActive < 0 || Motion.reduced) {
            capsuleLeftAnim.enabled = capsuleRightAnim.enabled = false;
            _capsuleLeft = l;
            _capsuleRight = r;
            capsuleLeftAnim.enabled = capsuleRightAnim.enabled = true;
        } else if (l >= _capsuleLeft) {          // moving right: the right edge leads
            _capsuleRight = r;
            _trailIsLeft = true;
            _trailTo = l;
            trailTimer.restart();
        } else {
            _capsuleLeft = l;
            _trailIsLeft = false;
            _trailTo = r;
            trailTimer.restart();
        }
        _lastActive = idx;
    }

    implicitWidth: Math.min(maxWidth, content.implicitWidth)
    implicitHeight: Tokens.barHeight
    clip: true

    Timer {
        id: trailTimer
        interval: Motion.catalogueMs("workspace.trailDelay", false)
        onTriggered: {
            if (root._trailIsLeft) root._capsuleLeft = root._trailTo;
            else root._capsuleRight = root._trailTo;
        }
    }
    Timer {
        id: placeTimer
        interval: 0
        onTriggered: root._placeCapsule()
    }
    onStripChanged: placeTimer.restart()

    // A click or the wheel on the strip's background.
    MouseArea {
        anchors.fill: parent
        onClicked: SurfaceManager.open("overview", {}, root.monitorName)
        onWheel: w => { if (w.angleDelta.y !== 0) root._wheel(w.angleDelta.y > 0 ? -1 : 1); }
    }
    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.surfaces.bar.pillGap
        IconButton {
            id: overviewButton
            anchors.verticalCenter: parent.verticalCenter
            size: "bar"
            glyph: "grid_view"
            tooltip: "Overview  Super+Tab"
            onClicked: SurfaceManager.open("overview", {}, root.monitorName)
        }
        Item {
            width: pillRow.implicitWidth
            height: Tokens.surfaces.bar.pillHeight
            anchors.verticalCenter: parent.verticalCenter
            // the accent capsule under the active pill (M-02)
            Rectangle {
                visible: root._lastActive >= 0
                x: root._capsuleLeft - pillRow.x
                width: Math.max(0, root._capsuleRight - root._capsuleLeft)
                height: parent.height
                radius: Tokens.surfaces.bar.pillRadius
                color: Tokens.accent
            }
            Row {
                id: pillRow
                spacing: Tokens.surfaces.bar.pillGap
                onWidthChanged: placeTimer.restart()
                Repeater {
                    id: pills
                    model: root.strip.pills
                    delegate: WorkspacePill {
                        id: pill
                        required property var modelData
                        required property int index
                        workspace: modelData
                        menuOpen: root._menuOpen
                        showIcons: root.showIcons && (root.collapse === 0 || (root.collapse === 1 && modelData.active))
                        // M-01: pill i starts i × workspaceStaggerMs into the intro
                        readonly property real _total: Math.max(1, Motion.ms("intro", false))
                        readonly property real _stagger: Tokens.surfaces.bar.workspaceStaggerMs
                        appear: root.introProgress >= 1 ? 1 : Math.max(0, Math.min(1,
                            (root.introProgress * _total - index * _stagger)
                            / Math.max(1, _total - (root.strip.pills.length - 1) * _stagger)))
                        onClicked: root._go(modelData)
                        onMiddleClicked: root._moveHere(modelData)
                        onRightClicked: (x, y) => root._menu(modelData, pill.x + pillRow.x + x, y)
                        onWheelStep: d => root._wheel(d)
                        property bool _wasUrgent: false
                        onWorkspaceChanged: {
                            if (workspace.urgent && !_wasUrgent) nudge();
                            _wasUrgent = !!workspace.urgent;
                        }
                    }
                }
            }
        }
        WorkspacePill {
            visible: !!root.strip.scratch
            anchors.verticalCenter: parent.verticalCenter
            scratch: true
            menuOpen: root._menuOpen
            workspace: root.strip.scratch || ({})
            onClicked: Hypr.toggleScratch()
        }
    }
    Behavior on _capsuleLeft { id: capsuleLeftAnim; SnappySpring {} }
    Behavior on _capsuleRight { id: capsuleRightAnim; SnappySpring {} }
}
