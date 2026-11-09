// Base type of the docked drawers that are not notch modes (Deck, Overview), hosted by DrawerSlot.
// The host contract and the content choreography (04 §3 rule 1, following `open`) come from
// Choreographed.
import QtQuick

Choreographed {
    shown: open

    property bool open: false

    // Still animating closed: DrawerSlot unloads the drawer once this is false (04 §8). The
    // default covers the content fade; a drawer whose geometry closes later binds that animation.
    property bool busy: leaving

    // This drawer's part of the frame shape.
    readonly property BulgeSpec bulge: BulgeSpec {}
}
