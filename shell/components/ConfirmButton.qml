import QtQuick
import qs.models
import qs.theme

// Small pill for a step that costs something (forgetting a network or device): the first click arms it, the second one confirms.
Item {
    id: button

    property string label
    property string confirmLabel: "Really?"
    property bool armed
    property int severity  // Enums.Severity, the colour of the armed state
    signal confirmed()
}
