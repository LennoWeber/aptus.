// The status cluster (surfaces/bar.md §6): one pill, `raised` on hover only, with the battery,
// volume, Bluetooth, network, DND and privacy items right to left; items open and close with M-04.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The Hyprland monitor name of this bar (the Deck opens there).
    property string monitorName: ""
    // Quiet bar (M-31b): only the items that keep (privacy, recording, battery ≤ 30 %) stay.
    property bool quiet: false

    // The status items now (bar.js statusItems), right to left.
    readonly property var items: []
    // Items that left but still close (M-04), by id.
    property var _leaving: ({})

    // The inputs of bar.md §6: click opens the Deck at the item's section ("" = the top), the
    // wheel on volume / battery steps volume / brightness, middle on volume mutes, right on
    // network / Bluetooth toggles Wi-Fi / Bluetooth.
    function _open(section: string): void { throw new Error("not implemented"); }
    function _wheel(id: string, direction: int): void { throw new Error("not implemented"); }
    function _middle(id: string): void { throw new Error("not implemented"); }
    function _right(id: string): void { throw new Error("not implemented"); }
}
