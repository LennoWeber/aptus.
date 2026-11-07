pragma Singleton
// Notch-mode id → the Component of its content (07 §5 MonitorState.notch). The Notch receives
// `components` from MonitorShell, so qs.surfaces.notch never imports the registry.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../core/js/rules.js" as Rules

Singleton {
    id: root

    // The interactive and passive notch modes ("card:<activity>" cards belong to the notch itself).
    readonly property var ids: Rules.NOTCH_MODES

    // id → Component (keysPeek uses the Keys sheet with args.peek).
    readonly property var components: ({})

    function component(id: string): Component { throw new Error("NotchModes.component: not implemented"); }
}
