// ErrorLine: the error state of 03 §8: one ink.sec line and a plain Retry button.
import QtQuick
import qs.core

Item {
    id: root

    // What happened and what to do ("Could not reach Open-Meteo. Check the connection.").
    property string text: ""
    // Show the Retry button.
    property bool retry: true
    signal retryRequested()
}
