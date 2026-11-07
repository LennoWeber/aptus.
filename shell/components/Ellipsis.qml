// Ellipsis: the loading state of 03 §8: three dots in ink.meta that fade in after 300 ms.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): three dots, opacity 0 until running has lasted Motion catalogue loadingDelay (300 ms).

    // Loading; the dots appear only if it lasts longer than Motion's loadingDelay.
    property bool running: false
}
