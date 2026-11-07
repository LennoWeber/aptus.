pragma Singleton
// Privacy: mic, camera, screencast in use.
// Owner: S3. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // apps using the microphone
    property var mic: []
    property var camera: []
    property bool screencast: false
}
