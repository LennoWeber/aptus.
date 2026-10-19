import QtQuick

// One candidate for the context zone in the middle of the bar.
QtObject {
    property int kind            // Enums.ContextKind
    property string text
    property string detail
    property int severity        // Enums.Severity
    property int priority        // higher wins the context zone
    property real progress       // 0..1, -1 if not applicable
}
