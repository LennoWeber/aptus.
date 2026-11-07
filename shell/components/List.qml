// List: A keyboard-navigable list of Rows with the current wash moving on the snappy spring.
import QtQuick
import qs.core

ListView {
    id: root

    // TODO(phase): ListView with highlight wash on the snappy spring and the 05 §5 keys.

    // Move the selection with the keyboard keys of 05 §5 (↑ ↓, Ctrl+P/N, PageUp/Down, Home/End).
    property bool keyNavigation: true
    signal activatedAt(int index)
}
