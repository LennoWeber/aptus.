import QtQuick
import qs.theme

// The body of the notch: opaque, a hairline instead of a shadow, hung from the top edge. Only the lower corners are
// round; the upper ones sit beyond the screen edge (the body is taller than it shows and clipped).
Item {
    id: shape

    property string look: "light"       // light | ink
    property real cornerRadius: 14      // of the lower corners
    property int severity: 0            // Enums.Severity, only an alert may carry one
    property real shownWidth            // the animated size of the body
    property real shownHeight
    default property alias content: inner.data

    Item {
        id: inner
    }
}
