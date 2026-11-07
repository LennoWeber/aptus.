// ListRow: List row (03 §9): 36 high (44 in Spotlight), leading icon, title, trailing meta or keycaps; current = wash.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): the list row of 03 §9: icon, title, subtitle, trailing; current wash; 05 §5 mouse rules.

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

    // Private state.
    readonly property bool _app: false
    readonly property bool _hasLead: false
    readonly property real _leadSize: 0
    // A ListView delegate whose view draws a highlight (List) leaves the current wash to it.
    readonly property bool _viewHighlights: false
}
