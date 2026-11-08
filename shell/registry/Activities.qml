pragma Singleton
// The notch's extension tables (surfaces/notch.md §4–§5): live activities and result cards.
// The Notch receives them from MonitorShell (it never imports the registry); each component lives
// in its owning stage's folder.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.surfaces.notch
import qs.surfaces.focus
import qs.surfaces.today
import qs.surfaces.capture
import qs.surfaces.session

Singleton {
    id: root

    // Live activities, in notch.md §4 order.
    readonly property var activityIds: ["recording", "timer", "meeting", "focus", "media", "progress"]
    // id → Component of an Activity (MediaActivity, ProgressActivity, FocusActivity,
    // TimerActivity, MeetingActivity, RecordingActivity).
    readonly property var activities: ({ recording: recordingA, timer: timerA, meeting: meetingA, focus: focusA, media: mediaA, progress: progressA })

    // Result cards: a toast payload with `card: <id>` is drawn by this component.
    readonly property var cardIds: ["capture", "colour", "stillOpen"]
    // id → Component of a NotchCard (CaptureCard, ColourCard, StillOpenCard).
    readonly property var cards: ({ capture: captureK, colour: colourK, stillOpen: stillOpenK })

    Component { id: recordingA; RecordingActivity {} }
    Component { id: timerA; TimerActivity {} }
    Component { id: meetingA; MeetingActivity {} }
    Component { id: focusA; FocusActivity {} }
    Component { id: mediaA; MediaActivity {} }
    Component { id: progressA; ProgressActivity {} }
    Component { id: captureK; CaptureCard {} }
    Component { id: colourK; ColourCard {} }
    Component { id: stillOpenK; StillOpenCard {} }
}
