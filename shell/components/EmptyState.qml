// EmptyState: Empty state (03 §9): glyph 40 in faint, one line sec, optional action.
import QtQuick
import qs.core

Item {
    id: root

    property string glyph: ""
    property string text: ""
    property string actionText: ""
    signal action()
}
