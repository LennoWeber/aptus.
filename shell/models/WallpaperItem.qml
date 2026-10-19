import QtQuick

// One wallpaper in the wallpaper picker.
QtObject {
    property string path
    property string name
    property string thumbnailPath
    property bool current

    function apply(): void {
        throw new Error("not implemented")
    }
}
