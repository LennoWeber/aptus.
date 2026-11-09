// DrawerSlot: holds one drawer and loads it only from opening until it has finished closing
// (04 §8: closed surfaces are not loaded). Frame and the Esc ladder talk to the slot, never to the
// drawer: it forwards the drawer's bulge (a closed one while nothing is loaded) and its back() step.
// The slot passes monitorName, open and args on; drawer-specific inputs go into `drawer` itself.
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root

    // The drawer to load: a Component whose root is a Drawer.
    required property Component drawer
    property string monitorName: ""
    property bool open: false
    property var args: ({})

    // The loaded drawer, null while it is not loaded.
    readonly property Drawer item: loader.item as Drawer
    // The drawer's part of the frame shape.
    readonly property BulgeSpec bulge: item ? item.bulge : _closed

    signal closeRequested()

    // Esc ladder (05 §3): the drawer's internal step back, false while it is not loaded.
    function back(): bool { return item ? item.back() : false; }

    readonly property BulgeSpec _closed: BulgeSpec {}
    // Loaded from opening until the drawer reports it is no longer busy after closing. The release
    // waits a turn, so the drawer's exit has started (and set `busy`) before it is checked.
    property bool _hold: false
    onOpenChanged: {
        if (open) _hold = true;
        else Qt.callLater(_release);
    }
    function _release(): void {
        if (!open && !(item && item.busy)) _hold = false;
    }

    Loader {
        id: loader
        anchors.fill: parent
        active: root.open || root._hold
        sourceComponent: root.drawer
    }
    Binding { target: root.item; property: "monitorName"; value: root.monitorName; when: root.item !== null }
    Binding { target: root.item; property: "open"; value: root.open; when: root.item !== null }
    Binding { target: root.item; property: "args"; value: root.args; when: root.item !== null }
    Connections {
        target: root.item
        function onBusyChanged(): void { root._release(); }
        function onCloseRequested(): void { root.closeRequested(); }
    }
}
