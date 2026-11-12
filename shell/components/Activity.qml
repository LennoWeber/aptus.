// Base type of a live activity (surfaces/notch.md §4–§5): its compact look in a slot beside the
// clock and its card (420 wide) when expanded. The Notch instantiates every registered activity
// once per monitor and shows, per slot, the live one with the highest priority.
import QtQuick
import qs.core

QtObject {
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
    // Its compact look stays when the bar slides out under a fullscreen window (notch.md §2:
    // recording); every other one leaves with the bar.
    property bool aboveFullscreen: false
    // The compact look (its implicitWidth is the slot width) and the card content. The Notch sets
    // these on the created item when it declares them: `activity` (this object), `monitorName`,
    // `pinned` (the card was opened by click and has the keyboard).
    property Component compact: null
    property Component card: null
    // The card's height for this activity (tokens surfaces.notch.cardHeights, notch.md §5).
    property real cardHeight: {
        const n = Tokens.surfaces.notch;
        return n && n.cardHeights && n.cardHeights[activity] !== undefined ? n.cardHeights[activity] : (n ? n.resultCardHeight : 0);
    }
    // Right-click menu rows (Menu model) and what the middle click does (notch.md §4).
    property var menu: []
    // A changed value nudges the compact look once (M-35-style pulse), e.g. a timer that starts ringing.
    property int pulseSerial: 0

    // Middle click on the compact look (notch.md §4: media play/pause, a ringing timer stops).
    function middleClick(): void {}
    // A row of `menu` was chosen (the Notch adds "Open in Today" itself).
    function menuTriggered(row: var): void {}
}
