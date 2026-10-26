pragma ComponentBehavior: Bound
import QtQuick
import QtQml
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.models
import qs.theme
import qs.osk
import qs.services

// Launcher overlay: pill, results, docked AI panel.
PanelWindow {
    id: win
    property var launcherState  // LauncherState
    property var shellState  // ShellState
    property var appSettings  // AppSettings
    // In AI mode the pill gives way to the docked panel (AiPanel): no blur, the screen stays usable.
    property real blurAmount: launcherState && launcherState.open && !launcherState.docked ? 1 : 0  // 0..1, drives the fade
    readonly property var placeholders: ["Search apps, calculate", "Search the web", "Search settings", "Ask a quick question", "Search clipboard"]
    readonly property var emptyHints: [
        "Type to find an app. Tab switches the mode.",
        "Enter opens the search in your browser.",
        "Type a setting. Enter opens it in the settings app.",
        "Ask a quick question in the side panel.",
        "Enter copies an entry. Shift+Delete removes it."
    ]

    Behavior on blurAmount { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

    // On the monitor that has focus.
    function pickScreen(monitor: var): var {
        const list = Quickshell.screens
        if (monitor) for (const s of list) if (s.name === monitor.name) return s
        return list.length > 0 ? list[0] : null
    }

    // Run the search for the current mode and text; local searches are well below one frame.
    function refresh(): void {
        if (!launcherState || !launcherState.open) return
        launcherState.results = Search.runSearch(launcherState.mode, launcherState.query)
        launcherState.selectedIndex = 0
        if (launcherState.mode === Enums.LauncherMode.Web) WebSuggest.request(launcherState.query.trim())
    }

    screen: pickScreen(Hyprland.focusedMonitor)
    visible: (launcherState && launcherState.open && !launcherState.docked) || blurAmount > 0.001
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aptus-launcher"
    WlrLayershell.keyboardFocus: launcherState && launcherState.open && !launcherState.docked ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property Item blurTarget: scrim
    // The Wayland blur type is not known to qmllint; it was verified at runtime (probe R2).
    // qmllint disable unresolved-type unqualified
    BackgroundEffect.blurRegion: Region { item: win.blurTarget }
    // qmllint enable unresolved-type unqualified

    onVisibleChanged: if (visible) Qt.callLater(() => pill.focusInput())

    // Clipboard results follow the history while the mode is open.
    Connections {
        target: Clipboard
        function onEntriesChanged() { if (win.launcherState && win.launcherState.mode === Enums.LauncherMode.Clipboard) win.refresh() }
    }

    Binding {
        target: Search
        property: "maxResults"
        value: win.appSettings ? (win.appSettings.get("launcher.maxResults") || 8) : 8
    }
    Binding {
        target: WebSuggest
        property: "enabled"
        value: win.appSettings ? win.appSettings.get("launcher.webSuggestions") === true : false
    }
    Binding {
        target: WebSuggest
        property: "engineId"
        value: win.appSettings ? win.appSettings.searchEngineId : "google"
    }
    // Suggestions arrive after the first results; the selection stays where it is.
    Connections {
        target: WebSuggest
        function onSuggestionsChanged() {
            if (!win.launcherState || !win.launcherState.open || win.launcherState.mode !== Enums.LauncherMode.Web) return
            const keep = win.launcherState.selectedIndex
            win.launcherState.results = Search.runSearch(win.launcherState.mode, win.launcherState.query)
            win.launcherState.selectedIndex = Math.min(keep, win.launcherState.results.length - 1)
        }
    }
    Binding {
        target: Search
        property: "showOpenWindows"
        value: win.appSettings ? win.appSettings.get("launcher.showOpenWindows") !== false : true
    }

    Connections {
        target: win.launcherState

        function onQueryChanged() { win.refresh() }
        function onModeChanged() {
            win.refresh()
            mergeAnimation.restart()
        }
        function onOpenChanged() {
            if (win.launcherState.open) {
                pill.clear()
                win.refresh()
                Qt.callLater(() => pill.focusInput())
            }
        }
    }

    // Mode shortcuts (Ctrl+1 ... Ctrl+5 by default, from settings).
    Instantiator {
        model: 5
        delegate: Shortcut {
            required property int index
            enabled: win.launcherState && win.launcherState.open
            sequence: (win.appSettings && win.appSettings.modeKeys && win.appSettings.modeKeys[index]) || ("Ctrl+" + (index + 1))
            onActivated: win.launcherState.setMode(index)
        }
    }

    // Blur plus a light veil. A click outside everything closes the launcher.
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Tokens.bg
        opacity: Tokens.overlayDim * win.blurAmount * 2
        MouseArea {
            anchors.fill: parent
            onClicked: win.launcherState.hide()
        }
    }

    Item {
        id: content
        width: Math.min(parent.width - 40, 820)
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: win.blurAmount
        // Rises 10 px into place while it fades in.
        y: 10 * (1 - win.blurAmount)

        Item {
            id: top
            y: parent.height * 0.22
            width: parent.width
            height: 52

            Pill {
                id: pill
                anchors { left: parent.left; right: icons.left; rightMargin: 10; top: parent.top; bottom: parent.bottom }
                mode: win.launcherState ? win.launcherState.mode : 0
                previousMode: win.launcherState ? win.launcherState.previousMode : 0
                switching: win.launcherState ? win.launcherState.switching : false
                query: win.launcherState ? win.launcherState.query : ""
                placeholder: win.placeholders[mode]
                onQueryEdited: text => win.launcherState.setQuery(text)
                onAccepted: if (win.launcherState.results && win.launcherState.results.length > 0) win.launcherState.activateSelected()
                onNavigationKey: event => {
                    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
                    const lst = win.launcherState
                    if (event.key === Qt.Key_Escape) lst.hide()
                    else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))) lst.moveSelection(1)
                    else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))) lst.moveSelection(-1)
                    else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                        const picked = lst.results && lst.results[lst.selectedIndex]
                        if (!picked || picked.mode !== Enums.LauncherMode.Clipboard) return
                        Clipboard.remove(picked.actionId)
                    }
                    else if (event.key === Qt.Key_Tab) lst.cycleMode(1)
                    else if (event.key === Qt.Key_Backtab) lst.cycleMode(-1)
                    else return
                    event.accepted = true
                }
            }

            ModeIcons {
                id: icons
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                currentMode: win.launcherState ? win.launcherState.mode : 0
                previousMode: win.launcherState ? win.launcherState.previousMode : 0
                onModeClicked: newMode => win.launcherState.setMode(newMode)
            }
        }

        Column {
            anchors { top: top.bottom; topMargin: 12; left: parent.left; right: parent.right }
            spacing: 10

            SpecialResult {
                readonly property var first: win.launcherState && win.launcherState.results && win.launcherState.results.length > 0 ? win.launcherState.results[0] : null
                visible: first !== null && first.kind === Enums.ResultKind.Calculation
                width: parent.width
                height: visible ? implicitHeight : 0
                title: first ? first.subtitle : ""
                value: first ? first.title : ""
                hint: "Enter copies"
            }

            ResultList {
                width: parent.width
                results: win.launcherState ? win.launcherState.results : []
                selectedIndex: win.launcherState ? win.launcherState.selectedIndex : 0
                mode: win.launcherState ? win.launcherState.mode : 0
                onSelectionRequested: index => win.launcherState.selectedIndex = index
                onResultActivated: index => {
                    win.launcherState.selectedIndex = index
                    win.launcherState.activateSelected()
                }
            }

            EmptyState {
                width: parent.width
                visible: !win.launcherState || !win.launcherState.results || win.launcherState.results.length === 0
                hint: win.launcherState && win.launcherState.mode === Enums.LauncherMode.Clipboard && !Clipboard.available ? "Clipboard history needs cliphist (not found)." : win.launcherState && win.launcherState.query.trim() !== "" ? "No results" : win.emptyHints[win.launcherState ? win.launcherState.mode : 0]
            }
        }
    }

    // The new mode symbol slides in over 140 ms.
    NumberAnimation {
        id: mergeAnimation
        target: pill
        property: "mergeProgress"
        from: 0
        to: 1
        duration: Tokens.durFast
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
        onFinished: win.launcherState.switching = false
    }

    // Drawn here because this overlay is full screen and would cover a separate keyboard window.
    OskPanel {
        z: 100
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
    }
}
