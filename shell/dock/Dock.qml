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
// comes back when the pointer touches the bottom edge. Looks: glass (blurred, see-through), solid, minimal (icons
// only). Icons near the pointer grow (setting dock.magnify) and an app that is starting hops until its window shows.
PanelWindow {
    id: dock

    required property var modelData
    property var appSettings  // AppSettings

    readonly property string look: appSettings ? appSettings.get("dock.look") || "glass" : "glass"
    readonly property bool magnify: appSettings ? appSettings.get("dock.magnify") !== false : true
    property real pointerX: -1e9       // pointer position from the middle of the dock; -1e9 when away
    property string launching          // key of the app that was just started, for the bounce
    property bool ready                // false for the first moment, so that the dock slides in when it appears

    readonly property bool reserveSpace: appSettings ? appSettings.get("dock.reserveSpace") === true : false
    readonly property bool autoHide: appSettings ? appSettings.get("dock.autoHide") === true : false
    readonly property int iconSize: appSettings ? appSettings.get("dock.iconSize") || 48 : 48
    readonly property var pinned: appSettings ? appSettings.get("dock.pinned") || [] : []
    readonly property var windows: ToplevelManager.toplevels.values
    readonly property var entries: build(pinned, windows)

    readonly property real maxZoom: magnify ? 1.6 : 1
    readonly property real cellRest: iconSize + 14   // width of one cell at rest
    readonly property real dividerWidth: 14
    // Index of the first app that is not kept in the dock, if there are kept apps before it.
    readonly property int dividerIndex: {
        const i = entries.findIndex(e => !e.pinned)
        return i > 0 ? i : -1
    }
    readonly property real restWidth: entries.length * cellRest + (dividerIndex >= 0 ? dividerWidth : 0)

    property var menuFor: null         // the entry the context menu belongs to
    readonly property bool menuOpen: menuFor !== null
    readonly property bool shown: ready && (!autoHide || hover.hovered || menuOpen)

    screen: modelData
    anchors { left: true; right: true; bottom: true }
    // Room for the zoomed icon, the name above it and the menu.
    implicitHeight: Math.round(iconSize * maxZoom) + 120
    // Like the bar: windows stop above the dock. Not while the dock hides itself.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: reserveSpace && !autoHide ? iconSize + 26 + 16 : 0
    color: "transparent"
    mask: Region { item: hot; Region { item: menuBox } }
    WlrLayershell.namespace: "aptus-dock"
    WlrLayershell.layer: WlrLayer.Top
    // The Wayland blur type is not known to qmllint; same as in the launcher.
    // qmllint disable unresolved-type unqualified
    BackgroundEffect.blurRegion: Region { item: dock.look === "glass" ? body : null; radius: body.radius }
    // qmllint enable unresolved-type unqualified

    Component.onCompleted: Qt.callLater(() => { dock.ready = true })

    // Pinned apps first, then every other open app.
    function build(pins: var, tops: var): var {
        const list = []
        for (const id of pins) {
            const de = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)
            if (de && !list.some(i => i.key === de.id)) list.push({ key: de.id, entry: de, pinned: true, windows: [] })
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

    // Zoom factor (1 .. maxZoom) of an icon whose centre is at `centerX` from the middle of the dock, at rest.
    function zoomAt(centerX: real): real {
        if (!isFinite(centerX)) throw new Error("invariant: Dock.zoomAt: centre is not a number")
        if (!magnify || pointerX < -1e8) return 1
        const d = (centerX - pointerX) / (iconSize * 1.1)
        return 1 + (maxZoom - 1) * Math.exp(-(d * d) / 2)
    }

    // True if a thin divider belongs before entries[index]: the first app that is not kept in the dock.
    function dividerBefore(index: int): bool {
        if (index < 0 || index >= entries.length) throw new Error("invariant: Dock.dividerBefore: index outside the entries")
        return index === dividerIndex
    }

    // Centre of entries[index] from the middle of the dock when nothing is zoomed.
    function restCentre(index: int): real {
        if (index < 0 || index >= entries.length) throw new Error("invariant: Dock.restCentre: index outside the entries")
        return -restWidth / 2 + index * cellRest + cellRest / 2 + (dividerIndex >= 0 && index >= dividerIndex ? dividerWidth : 0)
    }

    // Remember that `it` was started, so its icon bounces until a window shows up or a moment has passed.
    function markLaunching(it: var): void {
        if (!it || !it.key) throw new Error("invariant: Dock.markLaunching: entry without key")
        launching = it.key
        launchClear.restart()
    }

    function activate(it: var): void {
        if (it.windows.length === 0) {
            dock.markLaunching(it)
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

    Timer { id: launchClear; interval: 3500; onTriggered: dock.launching = "" }

    HyprlandFocusGrab {
        windows: [dock]
        active: dock.menuOpen
        onCleared: dock.menuFor = null
    }

    // The part that takes the pointer: the dock itself (and the room the zoomed icons need), or a thin strip at the
    // edge while hidden.
    Item {
        id: hot
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        width: Math.max(body.width, 160) + 16
        height: dock.shown ? body.height + 16 + (dock.pointerX > -1e8 ? dock.iconSize * (dock.maxZoom - 1) + 4 : 0) : 3
        HoverHandler {
            id: hover
            onPointChanged: dock.pointerX = hover.hovered ? point.position.x - hot.width / 2 : -1e9
            onHoveredChanged: if (!hovered) dock.pointerX = -1e9
        }
    }

    Rectangle {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: dock.shown ? parent.height - height - 8 : parent.height + 4
        Behavior on y { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        width: row.implicitWidth + 20
        height: dock.iconSize + 26
        radius: dock.look === "solid" ? 18 : 24
        color: dock.look === "glass" ? Tokens.glass : dock.look === "solid" ? Tokens.surface : "transparent"
        border.width: dock.look === "minimal" ? 0 : 1
        border.color: dock.look === "glass" ? Qt.rgba(1, 1, 1, 0.28) : Tokens.line

        // Soft shadow: a few wider, fainter outlines behind the panel.
        Repeater {
            model: dock.look === "minimal" ? 0 : 5
            delegate: Rectangle {
                required property int index
                z: -1
                anchors { fill: parent; margins: -(index + 1) * 3; topMargin: -(index + 1) * 2; bottomMargin: -(index + 1) * 4 }
                radius: body.radius + (index + 1) * 3
                color: "black"
                opacity: 0.05 - index * 0.008
            }
        }
        // Light edge on top of the glass.
        Rectangle {
            visible: dock.look === "glass"
            anchors { top: parent.top; topMargin: 1; left: parent.left; right: parent.right; leftMargin: body.radius; rightMargin: body.radius }
            height: 1
            color: Qt.rgba(1, 1, 1, 0.5)
        }

        Row {
            id: row
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 0 }
            height: parent.height
            Repeater {
                model: dock.entries
                delegate: Row {
                    id: slot
                    required property var modelData
                    required property int index
                    height: parent.height

                    // Thin divider between the kept apps and the ones that are only open.
                    Item {
                        visible: dock.dividerBefore(slot.index)
                        width: visible ? dock.dividerWidth : 0
                        height: parent.height
                        Rectangle {
                            anchors.centerIn: parent
                            width: 1
                            height: dock.iconSize * 0.7
                            color: Tokens.ink
                            opacity: 0.18
                        }
                    }
                    DockItem {
                        id: cell
                        info: slot.modelData
                        iconSize: dock.iconSize
                        zoom: dock.zoomAt(dock.restCentre(slot.index))
                        bouncing: dock.launching === slot.modelData.key && !cell.running
                        onActivated: dock.activate(slot.modelData)
                        onMenuRequested: dock.menuFor = slot.modelData

                        // Name above the icon while the pointer rests on it.
                        Rectangle {
                            visible: cell.hovered && !dock.menuOpen
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 12 + cell.iconSize * cell.zoom + 10 }
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
