// ListRow: List row (03 §9): 36 high (44 in Spotlight), leading icon, title, trailing meta or keycaps; current = wash.
import QtQuick
import qs.core

Item {
    id: root

    property string glyph: ""
    // App icon name instead of a glyph.
    property string icon: ""
    property string iconFallback: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property var keycaps: []
    property bool current: false
    property bool large: false
    property bool strong: true
    signal activated()
    signal contextRequested(real x, real y)
}
