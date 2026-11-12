pragma Singleton
import QtQuick
// Test double of Quickshell.Io FileViewError.
QtObject {
    // the values of Quickshell 0.3.2 (found by the A6 probe: FileNotFound 2, NotAFile 4)
    enum Error { Success, Unknown, FileNotFound, PermissionDenied, NotAFile }
    function toString(error: int): string { return error === 2 ? "file not found" : "error " + error; }
}
