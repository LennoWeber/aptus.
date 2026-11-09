// The progress activity's compact look (surfaces/notch.md §4): a 14 px ring and "42 %".
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The Progress item: { id, name, fraction, rate, remaining, cancellable, source }.
    property var item: null

    // TODO(phase): Ring 14 (fraction; -1 indeterminate still) + "42 %" (micro, tabular).
}
