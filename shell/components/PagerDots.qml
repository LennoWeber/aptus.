// PagerDots: Pager dots (03 §9): 6 px dots, ink.faint, current ink.sec.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): Row of dots per Tokens.pagerDots; click picks.

    property int count: 0
    property int current: 0
    signal picked(int index)
}
