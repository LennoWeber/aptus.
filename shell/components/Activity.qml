// Base type of a live activity (surfaces/notch.md §4–§5): its compact look in a slot beside the
// clock and its card (420 wide) when expanded. The Notch instantiates every registered activity
// once per monitor and shows, per slot, the live one with the highest priority.
import QtQuick

QtObject {
    // TODO(phase): cardHeight ← Tokens.surfaces.notch.cardHeights[activity] (notch.md §5), not 96.

    // Set by the host.
    property string monitorName: ""
    // The activity id ("media", "timer", "focus", "recording", "meeting", "progress").
    property string activity: ""
    // "left" | "right" (notch.md §4 table).
    property string slot: "right"
    // The activity exists now (media playing or recently paused, a timer running, …).
    property bool live: false
    // Current priority (Tokens.surfaces.notch.activityPriorities; media drops to mediaPaused).
    property int priority: 0
    // The compact look (its implicitWidth is the slot width) and the card content.
    property Component compact: null
    property Component card: null
    property real cardHeight: 96
    // Right-click menu rows (Menu model) and what the middle click does (notch.md §4).
    property var menu: []
    // A changed value nudges the compact look once (M-35-style pulse), e.g. a timer that starts ringing.
    property int pulseSerial: 0
}
