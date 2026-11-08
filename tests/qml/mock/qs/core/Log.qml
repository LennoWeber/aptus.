pragma Singleton
import QtQuick
// Test double of qs.core Log for tst_components (qmltestrunner cannot load Quickshell).
QtObject {
    function debug(c: string, m: string): void { console.log(c + ": " + m); }
    function info(c: string, m: string): void { console.log(c + ": " + m); }
    function warn(c: string, m: string): void { console.warn(c + ": " + m); }
    function error(c: string, m: string): void { console.error(c + ": " + m); }
}
