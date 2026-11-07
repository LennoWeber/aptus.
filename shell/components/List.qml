// List: A keyboard-navigable list of Rows with the current wash moving on the snappy spring.
import QtQuick
import qs.core

ListView {
    id: root

    // TODO(phase): ListView with highlight wash on the snappy spring and the 05 §5 keys.

    // Move the selection with the keyboard keys of 05 §5 (↑ ↓, Ctrl+P/N, PageUp/Down, Home/End).
    property bool keyNavigation: true
    signal activatedAt(int index)

    // Apply one key of 05 §5 (also for a surface whose field keeps the focus and forwards keys):
    // ↑ ↓ / Ctrl+P Ctrl+N one row, PageUp/PageDown one page, Home/End the ends, Enter
    // activatedAt(current). Shift+Enter and Ctrl+Enter stay with the surface. True when handled.
    function navigate(key: int, modifiers: int): bool { throw new Error("List.navigate: not implemented"); }
}
