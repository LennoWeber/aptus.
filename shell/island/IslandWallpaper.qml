pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.models
import qs.theme
import qs.services
import qs.components

// Wallpaper view: a gallery. A header (title, folder, number of pictures), a grid of 16:9 pictures that fits the number
// of pictures, a footer with the name of the chosen one. Arrow keys move in the grid, Enter sets and closes, a tap sets.
FocusScope {
    id: wall

    property int selectedIndex
    property real reveal: active ? 1 : 0      // 0..1, the grid fades in
    property bool active       // the view is the one shown
    property int columns: columnsFor(count)
    property int thumbWidth: thumbSizeFor(count).w
    property int thumbHeight: thumbSizeFor(count).h
    property int visibleRows: count === 0 ? 0 : Math.min(maxRows, Math.ceil(count / columns))
    property real contentWidth: count === 0 ? 480 : Math.max(480, columns * thumbWidth + (columns - 1) * gap + 2 * padding)
    property real contentHeight: count === 0 ? 210 : headerHeight + gridHeight + footerHeight
    property string folderLabel: Wallpaper.folder.replace(Quickshell.env("HOME"), "~")
    property int count: pictures.length
    property int gridHeight: visibleRows * thumbHeight + Math.max(0, visibleRows - 1) * gap
    property bool current: count > 0 && selectedIndex < count && pictures[selectedIndex].path === Wallpaper.current
    property color ink
    property color inkSoft
    property color line

    signal closeRequested()

    // The grid has at least one column and one row.
    Component.onCompleted: if (maxColumns < 1 || maxRows < 1) throw new Error("invariant: IslandWallpaper: the grid needs a column and a row")

    // The gallery: at most maxColumns pictures in a row and maxRows rows in view; the sizes of the parts around the grid.
    readonly property int maxColumns: 4
    readonly property int maxRows: 3
    readonly property int gap: 12
    readonly property int padding: 16
    readonly property int headerHeight: 44
    readonly property int footerHeight: 40

    readonly property var pictures: Wallpaper.list

    Behavior on reveal { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

    // Columns of the grid for a number of pictures: one per picture up to maxColumns.
    function columnsFor(count: int): int {
        if (count < 0) throw new Error("invariant: IslandWallpaper.columnsFor: negative number of pictures")
        return Math.max(1, Math.min(maxColumns, count))
    }

    // Size { w, h } of one picture for a number of pictures: large for one or two, smaller as there are more.
    function thumbSizeFor(count: int): var {
        if (count < 0) throw new Error("invariant: IslandWallpaper.thumbSizeFor: negative number of pictures")
        if (count === 1) return { w: 448, h: 252 }
        if (count === 2) return { w: 300, h: 169 }
        if (count <= 4) return { w: 220, h: 124 }
        return { w: 200, h: 112 }
    }

    // Move the selection in the grid by dx columns and dy rows, stopping at the edges.
    function moveSelection(dx: int, dy: int): void {
        if (dx !== 0 && dy !== 0) throw new Error("invariant: IslandWallpaper.moveSelection: a move is along one axis")
        if (pictures.length === 0) return
        let i = selectedIndex
        if (dx !== 0) i = Math.max(0, Math.min(pictures.length - 1, i + dx))
        if (dy !== 0) {
            const j = i + dy * columns
            if (j >= 0 && j < pictures.length) i = j
        }
        selectedIndex = i
    }

    // Select the picture at index (a tap or a hover).
    function setSelected(index: int): void {
        if (pictures.length === 0) return
        selectedIndex = Math.max(0, Math.min(pictures.length - 1, index))
    }

    // Set the chosen picture as wallpaper.
    function activateSelected(): void {
        if (pictures.length === 0) return
        Wallpaper.setWallpaper(pictures[selectedIndex].path)
    }

    // Scan the folder and select the current picture when the view is shown.
    function show(): void {
        Wallpaper.scan()
        const i = pictures.findIndex(p => p.path === Wallpaper.current)
        selectedIndex = Math.max(0, i)
        forceActiveFocus()
    }

    // Nothing to take back: the grid fades with the view.
    function hide(): void {
    }

    Connections {
        target: Wallpaper
        function onListChanged() {
            const i = wall.pictures.findIndex(p => p.path === Wallpaper.current)
            wall.selectedIndex = Math.max(0, i)
        }
    }

    onSelectedIndexChanged: grid.positionViewAtIndex(selectedIndex, GridView.Contain)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) { moveSelection(-1, 0); event.accepted = true }
        else if (event.key === Qt.Key_Right) { moveSelection(1, 0); event.accepted = true }
        else if (event.key === Qt.Key_Up) { moveSelection(0, -1); event.accepted = true }
        else if (event.key === Qt.Key_Down) { moveSelection(0, 1); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { activateSelected(); closeRequested(); event.accepted = true }
        else if (event.key === Qt.Key_Space) { activateSelected(); event.accepted = true }
    }

    // Header: the title, and on the right the folder and the number of pictures.
    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: wall.padding; rightMargin: wall.padding }
        height: wall.headerHeight
        opacity: wall.reveal
        Label {
            id: title
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "Wallpaper"
            role: Enums.TextRole.Title
            color: wall.ink
        }
        Label {
            anchors { left: title.right; leftMargin: 16; right: parent.right; verticalCenter: parent.verticalCenter }
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideMiddle
            text: wall.count > 0 ? wall.folderLabel + "  ·  " + wall.count + (wall.count === 1 ? " picture" : " pictures") : wall.folderLabel
            role: Enums.TextRole.Bar
            color: wall.inkSoft
        }
    }

    // Grid.
    GridView {
        id: grid
        visible: wall.count > 0
        anchors { horizontalCenter: parent.horizontalCenter; horizontalCenterOffset: wall.gap / 2; top: header.bottom }
        width: wall.columns * cellWidth   // the last cell includes the gap; the offset keeps the pictures centred
        height: wall.gridHeight
        cellWidth: wall.thumbWidth + wall.gap
        cellHeight: wall.thumbHeight + wall.gap
        clip: true
        interactive: wall.count > wall.columns * wall.visibleRows
        boundsBehavior: Flickable.StopAtBounds
        model: wall.pictures
        opacity: wall.reveal
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool chosen: index === wall.selectedIndex
            readonly property bool isCurrent: modelData.path === Wallpaper.current
            width: grid.cellWidth
            height: grid.cellHeight
            Rectangle {
                width: wall.thumbWidth
                height: wall.thumbHeight
                radius: 12
                color: wall.line
                clip: true
                border.width: cell.chosen ? 2 : 1
                border.color: cell.chosen ? wall.ink : wall.line
                scale: cell.chosen ? 1.0 : 0.97
                Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
                Image {
                    anchors { fill: parent; margins: cell.chosen ? 2 : 0 }
                    source: "file://" + cell.modelData.path
                    sourceSize.width: wall.thumbWidth * 2
                    sourceSize.height: wall.thumbHeight * 2
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }
                Rectangle {
                    visible: cell.isCurrent
                    anchors { right: parent.right; top: parent.top; margins: 8 }
                    width: 10; height: 10; radius: 5
                    color: Tokens.ok
                    border.width: 2
                    border.color: Tokens.surface
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { wall.setSelected(cell.index); wall.activateSelected() }
                }
            }
        }
    }

    // Footer: the name of the chosen picture, and the keys (only when the card is wide enough for both).
    Item {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: wall.padding; rightMargin: wall.padding }
        height: wall.footerHeight
        visible: wall.count > 0
        opacity: wall.reveal
        Label {
            anchors { left: parent.left; right: hint.visible ? hint.left : parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: wall.count > 0 && wall.selectedIndex < wall.count ? wall.pictures[wall.selectedIndex].name + (wall.current ? "   ·   current" : "") : ""
            role: Enums.TextRole.Bar
            color: wall.ink
            elide: Text.ElideMiddle
        }
        Label {
            id: hint
            visible: wall.width >= 600
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: "← ↑ ↓ →  choose     Enter  set"
            role: Enums.TextRole.Bar
            color: wall.inkSoft
        }
    }

    // Empty state: where to put pictures.
    Column {
        visible: wall.count === 0
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: 12 }
        width: parent.width - 2 * wall.padding
        spacing: 6
        Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "No pictures yet"; role: Enums.TextRole.Title; color: wall.ink }
        Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle; text: "Put pictures into " + wall.folderLabel; role: Enums.TextRole.Bar; color: wall.inkSoft }
        Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "or pick another folder in Settings, Appearance"; role: Enums.TextRole.Bar; color: wall.inkSoft }
    }
}
