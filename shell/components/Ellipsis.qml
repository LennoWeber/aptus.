// Ellipsis: the loading state of 03 §8: three dots in ink.meta that fade in after 300 ms.
import QtQuick
import qs.core

Item {
    id: root

    // Loading; the dots appear only if it lasts longer than Motion's loadingDelay.
    property bool running: false
}
