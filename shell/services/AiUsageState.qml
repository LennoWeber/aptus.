import QtQuick

// AI usage shown in the control center. No provider is wired up yet (the AI section adds them).
QtObject {
    property bool connected
    property string provider
    property string plan
    property real usedAmount
    property real limitAmount    // 0 if unlimited
    property string unit         // "tokens", "requests", ...
    property var resetAt         // Date
    property int severity        // Enums.Severity

    function refresh(): void {
        // Filled in by the AI section once providers exist.
    }
}
