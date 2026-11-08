pragma Singleton
// Notch-mode id → the Component of its content (07 §5 MonitorState.notch). The Notch receives
// `components` from MonitorShell, so qs.surfaces.notch never imports the registry.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../core/js/rules.js" as Rules
import qs.surfaces.spotlight
import qs.surfaces.switcher
import qs.surfaces.today
import qs.surfaces.session
import qs.surfaces.polkit
import qs.surfaces.gallery
import qs.surfaces.jot
import qs.surfaces.keys
import qs.surfaces.focus

Singleton {
    id: root

    // The interactive and passive notch modes ("card:<activity>" cards belong to the notch itself).
    readonly property var ids: Rules.NOTCH_MODES

    // id → Component (keysPeek uses the Keys sheet with args.peek).
    readonly property var components: ({
        spotlight: spotlightC,
        switcher: switcherC,
        today: todayC,
        session: sessionC,
        polkit: polkitC,
        gallery: galleryC,
        jot: jotC,
        keys: keysC,
        focusPicker: focusPickerC,
        keysPeek: keysC
    })

    function component(id: string): Component { return components[id] || null; }

    Component { id: spotlightC; Spotlight {} }
    Component { id: switcherC; SwitcherStrip {} }
    Component { id: todayC; Today {} }
    Component { id: sessionC; SessionSheet {} }
    Component { id: polkitC; PolkitPrompt {} }
    Component { id: galleryC; Gallery {} }
    Component { id: jotC; JotSheet {} }
    Component { id: keysC; KeysSheet {} }
    Component { id: focusPickerC; FocusPicker {} }
}
