pragma Singleton
// Logging (07-architecture §11). Categories: "surface", "service.<name>", "ipc", "perf", …
// Level from APTUS_LOG (default info) or `aptus msg shell log <level>`. Lines reach journald
// through the supervisor (tag aptus-shell). Never log notification bodies, clipboard content,
// passwords, calendar URLs or window titles above debug.
import QtQuick
import Quickshell

Singleton {
    id: root

    // 0 debug, 1 info, 2 warn, 3 error.
    property int level: 1
    readonly property var levelNames: ["debug", "info", "warn", "error"]

    function debug(category: string, message: string): void { throw new Error("Log.debug: not implemented"); }
    function info(category: string, message: string): void { throw new Error("Log.info: not implemented"); }
    function warn(category: string, message: string): void { throw new Error("Log.warn: not implemented"); }
    function error(category: string, message: string): void { throw new Error("Log.error: not implemented"); }
    // IPC `shell log <level>`: "debug" | "info" | "warn" | "error"; false for an unknown name.
    function setLevel(name: string): bool { throw new Error("Log.setLevel: not implemented"); }
    function write(lvl: int, category: string, message: string): void { throw new Error("Log.write: not implemented"); }
}
