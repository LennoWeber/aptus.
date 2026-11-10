pragma ComponentBehavior: Bound
// One workspace pill (surfaces/bar.md §3): number or name, up to three app icons and "+n", the
// urgent dot with its nudge (M-36); the scratch pill is a pill with `scratch`.
import QtQuick
import qs.core
import qs.services
import qs.components
import "js/bar.js" as B

Item {
    id: root

    // The workspace record (hypr.js); for the scratch pill: { name, windows, shown }.
    property var workspace: ({})
    // The scratch pill (a `terminal` glyph, accent ring while shown).
    property bool scratch: false
    // Draw the app icons (bar.workspaces.icons and the strip's collapse level).
    property bool showIcons: true
    // M-01: this pill's share of the intro (0 → 1, staggered by the strip).
    property real appear: 1

    // The pointer is over the pill (wash, tooltip after 600 ms).
    readonly property bool hovered: mouse.containsMouse

    signal clicked()
    signal middleClicked()
    // A right click at a point in this pill's coordinates (the strip opens the menu there).
    signal rightClicked(real x, real y)
    // A wheel step: -1 previous, +1 next.
    signal wheelStep(int direction)

    // M-36: the nudge's scale and when it last ran (ms; at most once per nudge.minInterval).
    property real _nudge: 1
    property real _lastNudge: 0

    // One nudge (M-36), unless one ran within nudge.minInterval.
    function nudge(): void {
        const now = Date.now();
        if (Motion.reduced || (_lastNudge > 0 && now - _lastNudge < Motion.catalogueValue("nudge.minInterval"))) return;
        _lastNudge = now;
        nudgeAnim.restart();
    }

    // Found by the probe (phase 5):
    // The bar's tokens, the pill's app classes (none for the scratch pill), the icons shown and
    // those behind "+n".
    readonly property var _bar: Tokens.surfaces.bar
    readonly property var _apps: scratch ? [] : (workspace.apps || [])
    readonly property int _iconCount: showIcons ? Math.min(_apps.length, _bar.pillMaxIcons) : 0
    readonly property int _more: showIcons ? Math.max(0, _apps.length - _bar.pillMaxIcons) : 0

    // The pill's width with its icons, and with the number only (the strip's collapse, bar.js).
    readonly property real fullWidth: 2 * _bar.pillPadH + numberLabel.implicitWidth + (scratch ? 0
        : Math.min(_apps.length, _bar.pillMaxIcons) * (_bar.pillIconSize + _bar.pillIconGap)
          + (_apps.length > _bar.pillMaxIcons ? moreLabel.implicitWidth + _bar.pillIconGap : 0))
    readonly property real numberWidth: 2 * _bar.pillPadH + numberLabel.implicitWidth

    implicitWidth: row.implicitWidth + 2 * _bar.pillPadH
    implicitHeight: _bar.pillHeight
    opacity: appear
    transform: Translate { y: (1 - root.appear) * -Tokens.s3 }

    Wash {
        anchors.fill: parent
        radius: root._bar.pillRadius
        hovered: root.hovered
        pressed: mouse.pressed
    }
    Rectangle {
        visible: root.scratch && !!root.workspace.shown
        anchors.fill: parent
        radius: root._bar.pillRadius
        color: "transparent"
        border.width: root._bar.scratchRingWidth
        border.color: Tokens.accent
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: root._bar.pillIconGap
        scale: root._nudge
        Glyph {
            visible: root.scratch
            anchors.verticalCenter: parent.verticalCenter
            name: "terminal"
            size: root._bar.pillIconSize
            colour: ComponentShared.ink("sec")
        }
        Label {
            id: numberLabel
            visible: !root.scratch
            anchors.verticalCenter: parent.verticalCenter
            type: "bar"
            tabular: true
            ink: root.workspace.active ? "onAccent" : "sec"
            text: root.workspace.label || ""
        }
        Repeater {
            model: root._apps.slice(0, root._iconCount)
            delegate: AppIcon {
                required property string modelData
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                size: root._bar.pillIconSize
                icon: Apps.iconFor(modelData)
                name: Apps.nameFor(modelData)
            }
        }
        Label {
            id: moreLabel
            visible: root._more > 0
            anchors.verticalCenter: parent.verticalCenter
            type: "micro"
            ink: root.workspace.active ? "onAccent" : "sec"
            text: "+" + Math.max(0, root._apps.length - root._bar.pillMaxIcons)
        }
    }
    Rectangle {
        visible: !!root.workspace.urgent
        width: root._bar.urgentDotSize
        height: width
        radius: width / 2
        color: Tokens.warn
        anchors.right: parent.right
        anchors.top: parent.top
        scale: root._nudge
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: e => {
            if (e.button === Qt.MiddleButton) root.middleClicked();
            else if (e.button === Qt.RightButton) root.rightClicked(e.x, e.y);
            else root.clicked();
        }
        onWheel: w => { if (w.angleDelta.y !== 0) root.wheelStep(w.angleDelta.y > 0 ? -1 : 1); }
    }
    Tooltip {
        target: root
        text: root.scratch ? "Scratch · " + (root.workspace.windows || 0) + " windows"
            : B.workspaceTooltip(root.workspace, root._apps.map(a => Apps.nameFor(a)))
        active: root.hovered
    }
    SequentialAnimation {
        id: nudgeAnim
        StandardAnimation { target: root; property: "_nudge"; to: Motion.catalogueValue("nudge.scale"); duration: Motion.catalogueValue("nudge.duration") / 2 }
        StandardAnimation { target: root; property: "_nudge"; to: 1; duration: Motion.catalogueValue("nudge.duration") / 2 }
    }
}
