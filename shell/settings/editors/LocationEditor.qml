import QtQuick

// Weather location.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): name search with coordinates filled in; Berlin by default.

    property string locationName
    property real latitude
    property real longitude
    signal locationChanged(string name, real latitude, real longitude)
}
