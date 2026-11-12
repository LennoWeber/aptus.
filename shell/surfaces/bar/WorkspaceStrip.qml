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
        void pillRow.width; void pillBox.x; void content.y;
        for (let i = 0; i < pills.count; i++) {
            const p = pills.itemAt(i) as WorkspacePill;
            // found in review: the pill box's own place in the strip counts too
            if (p) out.push({ workspace: p.workspace.id, x: content.x + pillBox.x + pillRow.x + p.x,
                              y: content.y + pillBox.y + pillRow.y + p.y, width: p.width, height: p.height });
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
    // Found in review: the wheel's carried delta (bar.js wheelSteps: small deltas add up).
    property real _wheelCarry: 0

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
    // Wave-2 review: the pills' model keyed by workspace id (bar.js syncIds), so a rebuild of the
    // strip updates the existing pills instead of recreating them all (the urgent nudge, hover
    // and tooltip need the same pill).
    ListModel { id: pillModel }
    // The record of a workspace id in the strip (a bare one while its row is being removed).
    function _record(id: int): var {
        for (const p of strip.pills) if (p.id === id) return p;
        return ({ id: id });
    }
    function _sync(): void {
        B.syncIds(pillModel, (strip.pills || []).map(p => p.id));
        placeTimer.restart();
    }
    onStripChanged: _sync()
    Component.onCompleted: _sync()

    // A click or the wheel on the strip's background.
    MouseArea {
        anchors.fill: parent
        onClicked: SurfaceManager.open("overview", {}, root.monitorName)
        onWheel: w => {
            const r = B.wheelSteps(root._wheelCarry, w.angleDelta.y);
            root._wheelCarry = r.carry;
            if (r.steps !== 0) root._wheel(r.steps > 0 ? -1 : 1);       // one per event: Hyprland's active workspace lags
        }
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
            id: pillBox
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
                    model: pillModel
                    delegate: WorkspacePill {
                        id: pill
                        required property int wsId
                        required property int index
                        workspace: root._record(wsId)
                        showIcons: root.showIcons && (root.collapse === 0 || (root.collapse === 1 && !!workspace.active))
                        // M-01: pill i starts i × workspaceStaggerMs into the intro
                        readonly property real _total: Math.max(1, Motion.ms("intro", false))
                        readonly property real _stagger: Tokens.surfaces.bar.workspaceStaggerMs
                        appear: root.introProgress >= 1 ? 1 : Math.max(0, Math.min(1,
                            (root.introProgress * _total - index * _stagger)
                            / Math.max(1, _total - (root.strip.pills.length - 1) * _stagger)))
                        onClicked: root._go(workspace)
                        onMiddleClicked: root._moveHere(workspace)
                        onRightClicked: (x, y) => { const q = pill.mapToItem(root, x, y); root._menu(pill.workspace, q.x, q.y); }
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
            workspace: root.strip.scratch || ({})
            onClicked: Hypr.toggleScratch()
        }
    }
    Behavior on _capsuleLeft { id: capsuleLeftAnim; SnappySpring {} }
    Behavior on _capsuleRight { id: capsuleRightAnim; SnappySpring {} }
}
