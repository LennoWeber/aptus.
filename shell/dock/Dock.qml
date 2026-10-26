pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.models
import qs.theme
import qs.components

// The dock: pinned apps and open windows in one row at the bottom edge. A fixed-size layer window with an input
// mask, so that nothing resizes when apps come and go. Floats over windows; with auto-hide it slides away and
// comes back when the pointer touches the bottom edge.
PanelWindow {
    id: dock

    required property var modelData
    property var appSettings  // AppSettings

    property string look: "glass"    // glass | solid | minimal (dock.look)
    property bool magnify              // zoom under the pointer (dock.magnify)
    property real pointerX: -1e9       // pointer position from the middle of the dock, -1e9 when away
    property bool ready                // false for the first moment, so the dock can slide in
    property real maxZoom              // largest zoom factor (1 without dock.magnify)
    property real cellRest             // width of one cell at rest
    property real dividerWidth         // width of the divider between kept and open-only apps
    property int dividerIndex          // index of the first open-only app after kept ones, -1 if none
    property real restWidth            // width of all cells at rest, divider included
    property string launching          // key of the app that was just started, for the bounce

    // TODO(phase 7): bind look to dock.look, magnify to dock.magnify; default autoHide is now false (the schema default), make the fallback agree.
    readonly property bool autoHide: appSettings ? appSettings.get("dock.autoHide") !== false : true
    readonly property int iconSize: appSettings ? appSettings.get("dock.iconSize") || 44 : 44
    readonly property var pinned: appSettings ? appSettings.get("dock.pinned") || [] : []
    readonly property var windows: ToplevelManager.toplevels.values
    readonly property var entries: build(pinned, windows)

    property var menuFor: null         // the entry the context menu belongs to
    readonly property bool menuOpen: menuFor !== null
    readonly property bool shown: !autoHide || hover.hovered || menuOpen

    // TODO(phase 7): ready starts false and turns true after the first frame (Qt.callLater) so the dock slides in; look and magnify become readonly bindings;
    // TODO(phase 7): fill maxZoom, cellRest, dividerWidth, dividerIndex and restWidth from the settings and entries.
    screen: modelData
    anchors { left: true; right: true; bottom: true }
    // TODO(phase 7): the window height follows the size setting: round(iconSize * maxZoom) + 120 (zoomed icon, tooltip, menu); iconSize goes up to 96.
    implicitHeight: 190
    // TODO(phase 7): dock.reserveSpace: exclusiveZone = dock height (icon size + 26 + 16) when on and autoHide is off, else 0.
    exclusiveZone: 0
    color: "transparent"
    // TODO(phase 7): blur behind the glass panel (BackgroundEffect.blurRegion, as the launcher does), only for look glass.
    mask: Region { item: hot; Region { item: menuBox } }
    WlrLayershell.namespace: "aptus-dock"
    WlrLayershell.layer: WlrLayer.Top

    // Pinned apps first, then every other open app.
    function build(pins: var, tops: var): var {
        const list = []
        for (const id of pins) {
            const de = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)
            if (de) list.push({ key: de.id, entry: de, pinned: true, windows: [] })
        }
        for (const t of tops) {
            if (!t.appId) continue
            const de = DesktopEntries.heuristicLookup(t.appId)
            let item = list.find(i => (de && i.entry && i.entry.id === de.id) || i.key.toLowerCase() === t.appId.toLowerCase())
            if (!item) {
                item = { key: de ? de.id : t.appId, entry: de, pinned: false, windows: [] }
                list.push(item)
            }
            item.windows.push(t)
        }
        return list
    }

    // Zoom factor (1 .. 1.6) of an icon whose centre is at `centerX` along the dock, from the pointer distance.
    function zoomAt(centerX: real): real {
        if (!isFinite(centerX)) throw new Error("invariant: Dock.zoomAt: centre is not a number")
        throw new Error("not implemented")
    }

    // True if a thin divider belongs before entries[index]: the first app that is not kept in the dock.
    function dividerBefore(index: int): bool {
        if (index < 0 || index >= entries.length) throw new Error("invariant: Dock.dividerBefore: index outside the entries")
        throw new Error("not implemented")
    }

    // Centre of entries[index] from the middle of the dock when nothing is zoomed.
    function restCentre(index: int): real {
        if (index < 0 || index >= entries.length) throw new Error("invariant: Dock.restCentre: index outside the entries")
        throw new Error("not implemented")
    }

    // Remember that `it` was started, so its icon bounces until a window shows up or a moment has passed.
    function markLaunching(it: var): void {
        if (!it || !it.key) throw new Error("invariant: Dock.markLaunching: entry without key")
        throw new Error("not implemented")
    }

    function activate(it: var): void {
        // TODO(phase 7): call markLaunching(it) before execute(), so the icon bounces while the app starts.
        if (it.windows.length === 0) {
            if (it.entry) it.entry.execute()
            return
        }
        // Several windows: each click goes to the next one.
        const at = it.windows.findIndex(w => w.activated)
        it.windows[(at + 1) % it.windows.length].activate()
    }

    function setPinned(it: var, on: bool): void {
        if (!appSettings || !it.entry) return
        const cur = (pinned || []).slice()
        const i = cur.indexOf(it.entry.id)
        if (on && i < 0) cur.push(it.entry.id)
        if (!on && i >= 0) cur.splice(i, 1)
        appSettings.set("dock.pinned", cur)
        appSettings.writeUserConfig()
    }

    HyprlandFocusGrab {
        windows: [dock]
        active: dock.menuOpen
        onCleared: dock.menuFor = null
    }

    // The part that takes the pointer: the dock itself, or a thin strip at the edge while hidden.
    Item {
        id: hot
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        width: Math.max(body.width, 160) + 16
        height: dock.shown ? body.height + 16 : 3
        // TODO(phase 7): feed pointerX from a second HoverHandler (point.position.x in the body), reset to -1 on leave.
        HoverHandler { id: hover }
    }

    Rectangle {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: dock.shown ? parent.height - height - 8 : parent.height + 4
        Behavior on y { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        // TODO(phase 7): glass/solid/minimal look: fill from Tokens.glass or Tokens.surface, none for minimal, radius, edge, light edge on top and a soft shadow;
        // TODO(phase 7): width and height must follow the zoomed row, not the rest size.
        width: row.implicitWidth + 16
        height: dock.iconSize + 26
        radius: 20
        color: Tokens.surface
        border.width: 1
        border.color: Tokens.line

        Row {
            id: row
            anchors.centerIn: parent
            Repeater {
                // TODO(phase 7): add a thin divider before the first non-pinned entry (dividerBefore); give each cell zoom = zoomAt(centre) when magnify is on.
                model: dock.entries
                delegate: DockItem {
                    id: cell
                    required property var modelData
                    info: modelData
                    iconSize: dock.iconSize
                    // TODO(phase 7): pass bouncing = (dock.launching === modelData.key).
                    onActivated: dock.activate(modelData)
                    onMenuRequested: dock.menuFor = modelData

                    // Name above the icon while the pointer rests on it.
                    Rectangle {
                        visible: cell.hovered && !dock.menuOpen
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top; bottomMargin: 8 }
                        width: tip.implicitWidth + 20
                        height: 26
                        radius: 8
                        color: Tokens.ink
                        Label {
                            id: tip
                            anchors.centerIn: parent
                            text: cell.name
                            role: Enums.TextRole.Bar
                            color: Tokens.bg
                        }
                    }
                }
            }
        }
    }

    // Context menu above the dock.
    Rectangle {
        id: menuBox
        visible: dock.menuOpen
        anchors { horizontalCenter: parent.horizontalCenter; bottom: body.top; bottomMargin: 8 }
        width: 200
        height: menuColumn.implicitHeight + 12
        radius: Tokens.radiusDropdown
        color: Tokens.surface
        border.width: 1
        border.color: Tokens.line

        Column {
            id: menuColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }

            Label {
                x: 8
                height: 26
                verticalAlignment: Text.AlignVCenter
                text: dock.menuFor && dock.menuFor.entry ? dock.menuFor.entry.name : (dock.menuFor ? dock.menuFor.key : "")
                font.weight: Font.DemiBold
                color: Tokens.inkSoft
            }
            Repeater {
                model: {
                    const it = dock.menuFor
                    if (!it) return []
                    const out = []
                    if (it.windows.length > 0 && it.entry) out.push({ id: "new", text: "New window" })
                    if (it.entry) out.push({ id: "pin", text: it.pinned ? "Remove from dock" : "Keep in dock" })
                    if (it.windows.length > 0) out.push({ id: "close", text: it.windows.length > 1 ? "Close all windows" : "Close window" })
                    return out
                }
                delegate: Item {
                    id: row2
                    required property var modelData
                    width: menuColumn.width
                    height: 34
                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: Tokens.ink
                        opacity: m.pressed ? 0.14 : m.containsMouse ? 0.08 : 0
                    }
                    Label {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: row2.modelData.text
                        color: row2.modelData.id === "close" ? Tokens.critical : Tokens.ink
                    }
                    MouseArea {
                        id: m
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            const it = dock.menuFor
                            dock.menuFor = null
                            if (!it) return
                            if (row2.modelData.id === "new") it.entry.execute()
                            else if (row2.modelData.id === "pin") dock.setPinned(it, !it.pinned)
                            else for (const w of it.windows) w.close()
                        }
                    }
                }
            }
        }
    }
}
