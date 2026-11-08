pragma Singleton
import QtQuick
// Test double of the Quickshell singleton: an icon theme that knows only "known".
QtObject {
    function iconPath(icon: string, check: bool): string { return icon === "known" ? "image://nonexistent/known" : ""; }
}
