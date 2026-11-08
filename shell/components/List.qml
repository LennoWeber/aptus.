// List: A keyboard-navigable list of Rows with the current wash moving on the snappy spring.
// Delegates are usually ListRows with `current: ListView.isCurrentItem`.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core

ListView {
    id: root

    // Move the selection with the keyboard keys of 05 §5 (↑ ↓, Ctrl+P/N, PageUp/Down, Home/End).
    property bool keyNavigation: true
    signal activatedAt(int index)

    // Apply one key of 05 §5 (also for a surface whose field keeps the focus and forwards keys):
    // ↑ ↓ / Ctrl+P Ctrl+N one row, PageUp/PageDown one page, Home/End the ends, Enter
    // activatedAt(current). Shift+Enter and Ctrl+Enter stay with the surface. True when handled.
    function navigate(key: int, modifiers: int): bool {
        if (count === 0) return false;
        const ctrl = (modifiers & Qt.ControlModifier) !== 0;
        const plain = (modifiers & (Qt.ControlModifier | Qt.ShiftModifier | Qt.AltModifier | Qt.MetaModifier)) === 0;
        const rowH = currentItem ? currentItem.height : Tokens.listRow.height;
        const page = Math.max(1, Math.floor(height / Math.max(1, rowH)));
        let i = currentIndex;
        if ((key === Qt.Key_Up && plain) || (key === Qt.Key_P && ctrl)) i = i < 0 ? 0 : i - 1;
        else if ((key === Qt.Key_Down && plain) || (key === Qt.Key_N && ctrl)) i = i < 0 ? 0 : i + 1;
        else if (key === Qt.Key_PageUp && plain) i = i - page;
        else if (key === Qt.Key_PageDown && plain) i = i + page;
        else if (key === Qt.Key_Home && plain) i = 0;
        else if (key === Qt.Key_End && plain) i = count - 1;
        else if ((key === Qt.Key_Return || key === Qt.Key_Enter) && plain) {
            if (currentIndex < 0) return false;
            root.activatedAt(currentIndex);
            return true;
        } else return false;
        i = Math.max(0, Math.min(count - 1, i));
        if (i !== currentIndex) {
            currentIndex = i;
            positionViewAtIndex(i, ListView.Contain);
        }
        return true;
    }

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    highlightFollowsCurrentItem: false
    highlight: Wash {
        x: root.currentItem ? root.currentItem.x : 0
        y: root.currentItem ? root.currentItem.y : 0
        width: root.currentItem ? root.currentItem.width : 0
        height: root.currentItem ? root.currentItem.height : 0
        radius: Tokens.listRow.radius
        current: true

        Behavior on y {
            enabled: !Motion.reduced
            SpringAnimation { spring: Motion.snappySpring; damping: Motion.snappyDamping; mass: Motion.snappyMass; epsilon: Motion.snappyEpsilon }
        }
        Behavior on height {
            enabled: !Motion.reduced
            SpringAnimation { spring: Motion.snappySpring; damping: Motion.snappyDamping; mass: Motion.snappyMass; epsilon: Motion.snappyEpsilon }
        }
    }
    Accessible.role: Accessible.List

    Keys.onPressed: event => {
        if (root.keyNavigation && root.navigate(event.key, event.modifiers)) event.accepted = true;
    }
}
