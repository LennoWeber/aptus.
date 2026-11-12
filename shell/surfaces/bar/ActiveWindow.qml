pragma ComponentBehavior: Bound
// The active window in the bar (surfaces/bar.md §4): app icon 16 · title in `bar` type, ink.sec,
// state glyphs after it; with no window the workspace's name. Title changes animate with M-03 and
// are throttled to 250 ms when they come faster than 4 a second.
import QtQuick
import qs.core
import qs.services
import qs.components
import "js/bar.js" as B

Item {
    id: root

    // The Hyprland monitor name of this bar.
    property string monitorName: ""
    // Found in phase 7: a menu is open on this monitor (no tooltip over it; under the menu's
    // catcher the hover state is not updated).
    // The focused window when it is on this monitor's active workspace (a Hypr window record), or null.
    property var window: null
    // What shows without a window: the active workspace's name ("" for none).
    property string fallback: ""
    // The most the title may take (bar.md §2: 420, 240 on a narrow monitor).
    property real maxWidth: 0

    // The title and icon on screen now and the title leaving (M-03).
    property string _title: ""
    property string _oldTitle: ""
    property string _icon: ""
    property string _appName: ""
    // The throttle state (bar.js): recent change times and when the shown title was set.
    property var _throttle: ({ changes: [], shownAt: 0 })
    // M-03 progress 0 → 1 of the current swap.
    property real _swap: 1
    // Found in review: the icon leaving (M-03 crossfades the icon too) and its swap progress.
    property string _oldIcon: ""
    property string _oldAppName: ""
    property real _iconSwap: 1
    // The window's state glyphs (bar.js windowGlyphs) as one string: a title change changes
    // nothing, so the Repeater keeps its Glyphs.
    readonly property string _glyphKey: B.windowGlyphs(window).join(" ")
    // The new icon's scale at swap progress 0 (title.iconScaleFrom; 1 with reduced motion).
    readonly property real _iconFrom: Motion.reduced ? 1 : Motion.catalogueValue("title.iconScaleFrom")
    // Found in review: the wheel's carried delta (small deltas add up).
    readonly property WheelStepper _wheel: WheelStepper {}

    // Found by the probe (phase 5):
    // The title and icon the label should show (the shown ones follow through the title throttle
    // and the crossfade, bar.md §4): the window's title (else its app's name) and its app icon.
    readonly property string _wantTitle: window ? (window.title || Apps.nameFor(window["class"])) : fallback
    readonly property string _wantIcon: window ? Apps.iconFor(window["class"]) : ""
    on_WantTitleChanged: _changed()
    on_WantIconChanged: _changed()
    Component.onCompleted: _show()

    // The window's title or class changed: show it now or after the throttle's delay.
    function _changed(): void {
        const now = Date.now();
        _throttle = B.noteTitleChange(_throttle, now);
        const wait = B.titleDelay(_throttle, now, Tokens.surfaces.bar.titleUpdateRateThreshold, Motion.catalogueMs("titleThrottle", false));
        if (wait <= 0) _show();
        else if (!throttle.running) { throttle.interval = wait; throttle.start(); }
    }
    // Swap to the pending title and icon (M-03).
    function _show(): void {
        if (_wantTitle === _title && _wantIcon === _icon) return;
        const iconChanged = _wantIcon !== _icon;
        if (iconChanged) { _oldIcon = _icon; _oldAppName = _appName; }
        _oldTitle = _title;
        _title = _wantTitle;
        _icon = _wantIcon;
        _appName = window ? Apps.nameFor(window["class"]) : "";
        _throttle = { changes: _throttle.changes, shownAt: Date.now() };
        swap.restart();
        if (iconChanged) iconSwap.restart();
    }
    // The window menu below the title (bar.md §4) and what its rows do.
    function _menu(): void {
        if (!window) return;
        const p = root.mapToItem(null, 0, height);
        SurfaceManager.openMenu(monitorName, {
            anchorX: p.x, anchorY: p.y + Tokens.s2, owner: "bar:window",
            model: B.windowMenu(window, Hypr.monitors.map(m => m.name), monitorName),
            onTriggered: row => root._menuTriggered(row)
        });
    }
    function _menuTriggered(row: var): void {
        const a = window ? window.address : "";
        if (!a || !row) return;
        const id = String(row.id || "");
        if (id === "float") Hypr.toggleFloating(a);
        else if (id === "pin") Hypr.togglePin(a);
        else if (id === "fullscreen") Hypr.toggleFullscreen(a);
        else if (id === "scratch") Hypr.moveToWorkspace(a, "special:scratch");
        else if (id === "close") Hypr.closeWindow(a);
        else if (id.indexOf("ws:") === 0) Hypr.moveToWorkspace(a, id.substring(3));
        else if (id.indexOf("mon:") === 0) Hypr.moveToMonitor(a, id.substring(4));
    }

    implicitHeight: Tokens.barHeight
    implicitWidth: maxWidth > 0 ? Math.min(maxWidth, content.implicitWidth) : 0
    visible: maxWidth > 0 && _title !== ""
    clip: true

    Timer { id: throttle; onTriggered: root._show() }
    StandardAnimation {
        id: swap
        target: root
        property: "_swap"
        from: 0
        to: 1
        duration: Motion.ms("fade", false)
    }
    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.s3
        // the app icon; on a change the old one fades out while the new one fades in from
        // title.iconScaleFrom (M-03)
        Item {
            id: icon
            visible: root._icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Tokens.surfaces.bar.titleIconSize
            height: width
            AppIcon {
                anchors.fill: parent
                visible: root._iconSwap < 1 && root._oldIcon !== ""
                size: parent.width
                icon: root._oldIcon
                name: root._oldAppName
                opacity: 1 - root._iconSwap
            }
            AppIcon {
                anchors.fill: parent
                size: parent.width
                icon: root._icon
                name: root._appName
                opacity: root._iconSwap
                scale: root._iconFrom + (1 - root._iconFrom) * root._iconSwap
            }
            StandardAnimation {
                id: iconSwap
                target: root
                property: "_iconSwap"
                from: 0
                to: 1
                duration: Motion.ms("fade", false)
            }
        }
        Item {
            id: titleBox
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(titleNew.implicitWidth,
                            Math.max(0, root.maxWidth - (icon.visible ? icon.width + content.spacing : 0) - glyphs.implicitWidth - content.spacing))
            height: titleNew.implicitHeight
            Label {
                id: titleOld
                width: parent.width
                type: "bar"
                ink: "sec"
                elide: Text.ElideRight
                text: root._oldTitle
                opacity: 1 - root._swap
                y: -Motion.catalogueValue("title.rise") * root._swap
                visible: root._swap < 1
            }
            Label {
                id: titleNew
                width: parent.width
                type: "bar"
                ink: "sec"
                elide: Text.ElideRight
                text: root._title
                opacity: root._swap
                y: Motion.catalogueValue("title.rise") * (1 - root._swap)
            }
        }
        Row {
            id: glyphs
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s1
            Repeater {
                model: root._glyphKey === "" ? [] : root._glyphKey.split(" ")
                delegate: Glyph {
                    required property string modelData
                    name: modelData
                    size: Tokens.glyphBar
                    colour: ComponentShared.ink("meta")
                }
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: e => {
            if (e.button === Qt.MiddleButton) { if (root.window) Hypr.closeWindow(root.window.address); }
            else root._menu();
        }
        onWheel: w => {
            const steps = root._wheel.feed(w.angleDelta.y);
            if (steps !== 0) Hypr.cycleFocus(steps > 0 ? -1 : 1);      // one per event: the focus lags
        }
    }
    Tooltip {
        target: root
        text: titleNew.truncated ? root._title : ""
        active: mouse.containsMouse
    }
}
