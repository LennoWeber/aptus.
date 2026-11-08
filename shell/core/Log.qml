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
    property int level: Math.max(0, levelNames.indexOf(String(Quickshell.env("APTUS_LOG") || "info")))
    readonly property var levelNames: ["debug", "info", "warn", "error"]

    function debug(category: string, message: string): void { write(0, category, message); }
    function info(category: string, message: string): void { write(1, category, message); }
    function warn(category: string, message: string): void { write(2, category, message); }
    function error(category: string, message: string): void { write(3, category, message); }
    // IPC `shell log <level>`: "debug" | "info" | "warn" | "error"; false for an unknown name.
    function setLevel(name: string): bool {
        const i = levelNames.indexOf(name);
        if (i < 0) return false;
        level = i;
        return true;
    }
    function write(lvl: int, category: string, message: string): void {
        if (lvl < level) return;
        const line = levelNames[lvl] + " " + category + ": " + message;
        if (lvl >= 3) console.error(line);
        else if (lvl === 2) console.warn(line);
        else console.info(line);
    }
}
