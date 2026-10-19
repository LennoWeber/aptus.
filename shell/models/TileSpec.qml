import QtQuick

// Layout description of one control center tile.
QtObject {
    property int tileId          // Enums.TileId
    property string title
    property int column
    property int row
    property int columnSpan
    property int rowSpan
    property bool visible
}
