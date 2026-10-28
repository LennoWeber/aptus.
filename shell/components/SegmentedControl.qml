import QtQuick
import qs.theme

// A row of mutually exclusive choices in one pill (scale, refresh rate).
Item {
    id: control

    property var options: []   // list of { label, value }
    property var current       // the value of the chosen option
    signal picked(var value)
}
