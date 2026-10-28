import QtQuick
import qs.theme

// A one-line text field in a soft pill.
Surface {
    id: field

    property alias text: input.text
    property string placeholder
    property bool secret
    signal accepted()
}
