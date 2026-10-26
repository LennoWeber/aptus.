import QtQuick
import qs.models
import qs.theme
import qs.components

// The lower part of the hover card: the power profile and the shortcuts that open a view of the island.
Item {
    id: actions

    property var powerProfileState
    property color ink
    property color inkSoft
    property color line
    property color fill

    signal viewRequested(int view)      // Enums.IslandView

    // Set the power profile (Enums.PowerMode).
    function setProfile(profile: int): void {
        if (profile < Enums.PowerMode.Saver || profile > Enums.PowerMode.Performance) throw new Error("invariant: IslandQuickActions.setProfile: unknown profile")
        if (!powerProfileState) throw new Error("invariant: IslandQuickActions.setProfile: no power profile state")
        throw new Error("not implemented")
    }
}
