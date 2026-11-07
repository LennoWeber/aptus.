pragma Singleton
// Bt: adapter, devices, pairing.
// Owner: S3 (status), S5 (pages). Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // an adapter exists
    property bool available: false
    property bool enabled: false
    // connected devices: [{ name, battery }]
    property var connected: []
}
