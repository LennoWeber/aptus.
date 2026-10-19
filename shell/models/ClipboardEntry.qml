import QtQuick

// One entry of the clipboard history (cliphist).
QtObject {
    property string id
    property string kind             // "text" | "image"
    property string preview          // shortened text, or image dimensions
    property string imagePath        // thumbnail for images, empty for text
    property var copiedAt            // Date
    property bool pinned

    // Put this entry back on the clipboard.
    function copyBack(): void {
        throw new Error("not implemented")
    }

    function togglePin(): void {
        throw new Error("not implemented")
    }

    function remove(): void {
        throw new Error("not implemented")
    }
}
