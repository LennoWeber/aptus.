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
import qs.services
import qs.surfaces.wallpaper
import qs.surfaces.frame
import qs.surfaces.bar
import qs.surfaces.notch
import qs.surfaces.deck
import qs.surfaces.overview
import qs.surfaces.capture

Scope {
    id: root

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
    readonly property MonitorState monitor: SurfaceManager.monitors[name] || null
    // Whether this monitor's shell layer takes the keyboard (MonitorState.keyboard).
    readonly property bool keyboard: monitor ? monitor.keyboard : false

    // Deck and Overview step back inside themselves before they close (the Esc ladder, 05 §3).
    Component.onCompleted: {
        SurfaceManager.registerBack(name, "deck", () => deck.back());
        SurfaceManager.registerBack(name, "overview", () => overview.back());
    }
    Component.onDestruction: {
        SurfaceManager.unregisterBack(name, "deck");
        SurfaceManager.unregisterBack(name, "overview");
    }

    WallpaperLayer {
        screen: root.modelData
        monitorName: root.name
        source: Wallpaper.pathFor(root.name)
        fill: Config.get("wallpaper.fill")
        focus: Config.get("wallpaper.focus")
    }

    // aptus-reserve: only the exclusive zone for the bar (07 §4); draws nothing, takes no input.
    PanelWindow {
        screen: root.modelData
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "aptus-reserve"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; left: true; right: true }
        implicitHeight: Tokens.barHeight
        exclusiveZone: Tokens.barHeight
        color: "transparent"
        mask: Region {}
    }

    // aptus-shell: frame, bar, notch, drawers, menus, passive content and the capture overlay.
    PanelWindow {
        id: shellWindow
        screen: root.modelData
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "aptus-shell"
        WlrLayershell.keyboardFocus: root.keyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        // Input: the bar band (a 2 px strip under a fullscreen window, P-11), the notch, and the
        // whole monitor while an interactive surface or a menu is open (the away catcher, 05 §3;
        // MonitorState.interactive includes menus). MenuHost lies above Deck and Overview.
        mask: Region {
            item: root.monitor && root.monitor.interactive ? content : barInput
            Region { item: notch.maskItem }
        }

        Item {
            id: content
            anchors.fill: parent

            // Away catcher: a click outside the open surface closes it and focuses the window under
            // the pointer, so closing never costs an extra click (05 §3).
            MouseArea {
                anchors.fill: parent
                enabled: root.monitor !== null && root.monitor.interactive
                acceptedButtons: Qt.AllButtons
                onPressed: mouse => {
                    const t = root.monitor.top;
                    if (t !== "") SurfaceManager.close(t, root.name);
                    const w = Hypr.windowAt(root.name, mouse.x, mouse.y);
                    if (w) Hypr.focusWindow(w.address);
                }
            }

            Frame {
                id: frame
                anchors.fill: parent
                monitor: root.monitor
                introProgress: root.introProgress
                hidden: root.monitor ? root.monitor.fullscreen : false
                revealed: barInput.revealed
                bulges: [notch.bulge, deck.bulge, overview.bulge]
            }
            Bar {
                id: bar
                width: parent.width
                monitor: root.monitor
                introProgress: root.introProgress
                notchWidth: notch.restWidth
                hide: frame.hide
            }
            // The input part of the bar band; under a fullscreen window only a 2 px strip, and a
            // 400 ms push against it brings the bar back (M-31, catalogue fullscreen.hotEdgePush).
            MouseArea {
                id: barInput
                width: parent.width
                height: frame.hidden && !revealed ? (Motion.catalogue.fullscreen ? Motion.catalogue.fullscreen.hotEdge : 2) : Tokens.barHeight
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                property bool revealed: false
                onContainsMouseChanged: {
                    if (containsMouse && frame.hidden) pushTimer.restart();
                    else { pushTimer.stop(); if (!containsMouse) revealed = false; }
                }
                Timer {
                    id: pushTimer
                    interval: Motion.catalogueMs("fullscreen.hotEdgePush", false)
                    onTriggered: barInput.revealed = true
                }
            }
            Notch {
                id: notch
                width: parent.width
                height: parent.height
                monitor: root.monitor
                introProgress: root.introProgress
                modeComponents: root.notchModes
                activityComponents: root.activities
                cardComponents: root.cards
            }
            Deck {
                id: deck
                anchors.fill: parent
                monitorName: root.name
                open: root.monitor ? root.monitor.deck : false
                args: root.monitor ? root.monitor.deckArgs : ({})
                onCloseRequested: SurfaceManager.close("deck", root.name)
            }
            Overview {
                id: overview
                anchors.fill: parent
                monitorName: root.name
                open: root.monitor ? root.monitor.overview : false
                args: root.monitor ? root.monitor.overviewArgs : ({})
                pillRects: bar.pillRects
                onCloseRequested: SurfaceManager.close("overview", root.name)
            }
            MenuHost {
                anchors.fill: parent
                monitor: root.monitor
            }
            CaptureOverlay {
                anchors.fill: parent
                monitor: root.monitor
                active: root.monitor ? root.monitor.capture !== null : false
            }
        }
    }

    RecFrame { monitorName: root.name }
}
