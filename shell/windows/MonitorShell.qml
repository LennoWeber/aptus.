// The layers of one monitor (07-architecture §4): aptus-wallpaper (Background), aptus-reserve
// (Top, exclusive zone = bar height), aptus-shell (Overlay: frame, bar, notch, drawers, menus,
// passive content, capture overlay) and the stage-owned aptus-recframe. Created per screen by
// shell.qml; every surface it hosts comes from its stage folder, so stages never edit this file.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components

Scope {
    id: root

    // TODO(phase): monitor ← SurfaceManager.monitorState(name); keyboard ← monitor.keyboard.
    // TODO(phase): every PanelWindow below: screen: modelData (multi-monitor); colour "transparent"
    //   on aptus-reserve and aptus-shell (the QsWindow default would show through glass).
    // TODO(phase): WallpaperLayer { monitorName; source: Wallpaper.pathFor(name); fill ← Config
    //   wallpaper.fill; focus ← Config wallpaper.focus } (Background, aptus-wallpaper).
    // TODO(phase): aptus-reserve: PanelWindow on Top, anchored top/left/right, height and exclusiveZone
    //   = Tokens.barHeight, empty mask, no keyboard (07 §4).
    // TODO(phase): aptus-shell: PanelWindow on Overlay, all edges, ExclusionMode.Ignore, keyboardFocus
    //   Exclusive ↔ None from `keyboard`.
    // TODO(phase): aptus-shell mask: bar + notch + open drawers; whole monitor while interactive (away
    //   catcher); under a fullscreen window a 2 px top strip (P-11), the bar while revealed.
    // TODO(phase): inside it, bottom to top: Frame { bulges: notch, deck, overview; introProgress },
    //   Bar { introProgress; notchWidth ← notch.restWidth }, Notch { modeComponents: notchModes;
    // TODO(phase): …activityComponents: activities; cardComponents: cards }, Deck, Overview
    //   { pillRects: bar.pillRects }, MenuHost, CaptureOverlay (top, exclusive).
    // TODO(phase): M-31: Frame.hidden ← monitor.fullscreen; a 400 ms push against the top strip
    //   (catalogue fullscreen.hotEdgePush) sets Frame.revealed; leaving the bar clears it.
    // TODO(phase): away catcher: a click outside the open surface → SurfaceManager.close(monitor.top,
    //   name), then Hypr.focusWindow(Hypr.windowAt(…)) so the click reaches the window (05 §3).
    // TODO(phase): RecFrame { monitorName } (S9 fills it).
    // TODO(phase): while a menu is open the mask covers the monitor (rules.interactive includes menus);
    //   MenuHost above Deck and Overview; registerBack for "deck" and "overview" (their back()).

    // The screen (Variants model data).
    required property ShellScreen modelData
    // Notch-mode id → Component, from qs.registry NotchModes (passed in by shell.qml).
    property var notchModes: ({})
    // Activity and card tables, from qs.registry Activities (passed in by shell.qml).
    property var activities: ({})
    property var cards: ({})
    // 0 → 1 during the session intro (M-01).
    property real introProgress: 1

    // The Hyprland monitor name of this screen.
    readonly property string name: modelData ? modelData.name : ""
    // This monitor's state in the SurfaceManager.
    readonly property MonitorState monitor: null
    // Whether this monitor's shell layer takes the keyboard (MonitorState.keyboard).
    readonly property bool keyboard: false
}
