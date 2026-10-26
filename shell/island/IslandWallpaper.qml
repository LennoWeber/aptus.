pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.services
import qs.components

// Wallpaper view: the pictures come out of the island one after the other as a row of cards; the one in the middle
// is chosen with the arrow keys, the wheel or a tap, and set at once.
FocusScope {
    id: wall

    property int selectedIndex
    // TODO(phase 7, Island-Galerie): No staggered 520 ms reveal: the grid fades in with 140 ms; reveal can stay as a 0..1 value for the fade.
    property real reveal: active ? 1 : 0      // 0..1, how far the cards have come out of the island
    property bool active       // the view is the one shown
    property int columns            // columns of the grid
    property int thumbWidth         // size of one picture in the grid
    property int thumbHeight
    property int visibleRows        // rows shown at once, the grid scrolls beyond that
    property real contentWidth      // size this view wants (Island.sizeFor reads it)
    property real contentHeight
    property string folderLabel     // the folder shown in the header, with ~ for home
    property int count              // number of pictures
    property int gridHeight         // height of the visible grid
    property bool current           // the chosen picture is the wallpaper now
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

    // How many cards are shown around the middle one.
    readonly property int visibleSide: 3
    readonly property int cardWidth: 200
    readonly property int cardHeight: 112
    readonly property var pictures: Wallpaper.list

    Behavior on reveal { NumberAnimation { duration: 520; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

    // Move the middle card by delta pictures.
    function step(delta: int): void {
        if (pictures.length === 0) return
        selectedIndex = Math.max(0, Math.min(pictures.length - 1, selectedIndex + delta))
    }

    // Columns of the grid for a number of pictures: one per picture up to maxColumns.
    function columnsFor(count: int): int {
        if (count < 0) throw new Error("invariant: IslandWallpaper.columnsFor: negative number of pictures")
        throw new Error("not implemented")
    }

    // Size { w, h } of one picture for a number of pictures: large for one or two, smaller as there are more.
    function thumbSizeFor(count: int): var {
        if (count < 0) throw new Error("invariant: IslandWallpaper.thumbSizeFor: negative number of pictures")
        throw new Error("not implemented")
    }

    // Move the selection in the grid by dx columns and dy rows, stopping at the edges.
    function moveSelection(dx: int, dy: int): void {
        if (dx !== 0 && dy !== 0) throw new Error("invariant: IslandWallpaper.moveSelection: a move is along one axis")
        throw new Error("not implemented")
    }

    // Select the picture at index (a tap or a hover).
    function setSelected(index: int): void {
        throw new Error("not implemented")
    }

    // Set the middle picture as wallpaper.
    function activateSelected(): void {
        if (pictures.length === 0) return
        Wallpaper.setWallpaper(pictures[selectedIndex].path)
    }

    // Scan the folder and start the reveal when the view is shown.
    function show(): void {
        Wallpaper.scan()
        const i = pictures.findIndex(p => p.path === Wallpaper.current)
        selectedIndex = Math.max(0, i)
        forceActiveFocus()
    }

    // Take the cards back when the view is left.
    function hide(): void {
    }

    Connections {
        target: Wallpaper
        function onListChanged() {
            const i = wall.pictures.findIndex(p => p.path === Wallpaper.current)
            wall.selectedIndex = Math.max(0, i)
        }
    }

    // TODO(phase 7, Island-Galerie): Arrows move in the grid (moveSelection(dx, dy)): left, right, up, down; Enter sets and closes, Space sets, Esc closes.
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) { step(-1); event.accepted = true }
        else if (event.key === Qt.Key_Right) { step(1); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { activateSelected(); closeRequested(); event.accepted = true }
        else if (event.key === Qt.Key_Space) { activateSelected(); event.accepted = true }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => wall.step(event.angleDelta.y < 0 || event.angleDelta.x < 0 ? 1 : -1)
    }

    // TODO(phase 7, Island-Galerie): The seven slots of the carousel become a header (title, count, folder), a GridView of 16:9 thumbnails (columns, thumbWidth, thumbHeight, visibleRows,
    // TODO(phase 7, Island-Galerie): async, sourceSize about twice the shown size), a footer (name, "Current" marker, key hint), and an empty state with the folder path.
    // TODO(phase 7, Island-Galerie): Elide long folder paths in header and empty state; show the key hint only when the card is wide; one picture gets 448 x 252.
    Repeater {
        // Seven slots around the middle; the picture of a slot is selectedIndex + offset.
        model: wall.visibleSide * 2 + 1
        delegate: Item {
            id: slot
            required property int index
            readonly property int offset: index - wall.visibleSide
            readonly property int pictureIndex: wall.selectedIndex + offset
            readonly property bool valid: pictureIndex >= 0 && pictureIndex < wall.pictures.length
            // The cards leave the island from the middle, the near ones first.
            readonly property real p: Math.max(0, Math.min(1, (wall.reveal - Math.abs(offset) * 0.09) / (1 - wall.visibleSide * 0.09)))
            readonly property bool isMiddle: offset === 0
            visible: valid && p > 0.01
            width: wall.cardWidth
            height: wall.cardHeight
            x: wall.width / 2 - width / 2 + offset * (wall.cardWidth + 16) * p
            y: 18 + (1 - p) * -40
            scale: (isMiddle ? 1.12 : 0.9) * (0.35 + 0.65 * p)
            opacity: p * (1 - Math.abs(offset) * 0.16)
            z: 10 - Math.abs(offset)
            Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: wall.line
                clip: true
                border.width: slot.isMiddle ? 2 : 1
                border.color: slot.isMiddle ? wall.ink : wall.line
                Image {
                    anchors.fill: parent
                    anchors.margins: 0
                    source: slot.valid ? "file://" + wall.pictures[slot.pictureIndex].path : ""
                    sourceSize.width: 400
                    sourceSize.height: 225
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }
                // current wallpaper: a small ink dot
                Rectangle {
                    visible: slot.valid && wall.pictures[slot.pictureIndex].path === Wallpaper.current
                    anchors { right: parent.right; top: parent.top; margins: 8 }
                    width: 10
                    height: 10
                    radius: 5
                    color: Tokens.ok
                    border.width: 2
                    border.color: Tokens.surface
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (slot.isMiddle) wall.activateSelected()
                    else wall.selectedIndex = slot.pictureIndex
                }
            }
        }
    }

    Label {
        visible: wall.pictures.length > 0
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 14 }
        text: wall.pictures.length > 0 && wall.selectedIndex < wall.pictures.length ? wall.pictures[wall.selectedIndex].name : ""
        role: Enums.TextRole.Bar
        color: wall.inkSoft
        opacity: wall.reveal
    }
    Label {
        visible: wall.pictures.length === 0
        anchors.centerIn: parent
        text: "No pictures in " + Wallpaper.folder
        color: wall.inkSoft
    }
}
