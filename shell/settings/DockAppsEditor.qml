pragma ComponentBehavior: Bound
import QtQuick
import qs.theme
import qs.components

// Editor for the apps kept in the dock: order, removal and a picker of the installed apps. Only declarations here.
Column {
    id: editor

    property var apps: []              // saved desktop entry ids, in dock order
    property bool picking              // the list of installed apps is open
    property string filter             // text typed in the picker
    signal changed(var apps)           // the whole new list
}
