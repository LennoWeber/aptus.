pragma Singleton
// Keys: bind table, descriptions (hyprctl binds -j, known-binds.json).
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    property var binds: []
}
