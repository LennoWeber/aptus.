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
}
