pragma Singleton
import QtQuick
// Test double of Quickshell.Io FileViewError.
QtObject {
    enum Error { Success, FileNotFound }
    function toString(error: int): string { return error === 1 ? "file not found" : "error " + error; }
}
