pragma Singleton
// Weather: current, 12 h, notable change (Open-Meteo, only with a location).
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    property var current: null
}
