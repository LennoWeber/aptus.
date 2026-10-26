import QtQuick
import qs.theme
import qs.components

// Sub-heading inside a category page: a small title over a quiet rule. Only declarations here.
Item {
    id: header

    property string title
    property bool first                // the first heading of a page needs less air above it
}
