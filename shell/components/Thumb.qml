// Thumb: A rounded image thumbnail (wallpapers, screenshots, covers).
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): the size default comes from Tokens.windowRadius, not a literal.
    // TODO(phase): an Image thumbnail with radius clip and a loading wash.

    property string source: ""
    property real radius: 10
    property bool selected: false

    // Private state.
    readonly property real _out: 0
}
