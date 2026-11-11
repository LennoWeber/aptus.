pragma ComponentBehavior: Bound
// A toast (surfaces/notch.md §6): app icon 24, app · time, close on hover, title, body ≤ 2 lines,
// image 48, up to three quiet action buttons, the inline reply field; the stack toast and the held
// summary are toasts too. Entrance M-06: icon 0.6 → 1, title then body rise 6 px, 40 ms apart.
import QtQuick
import qs.core
import qs.components
import "../../core/js/format.js" as F
import "js/notch.js" as NJ

Item {
    id: root

    // The Hyprland monitor name.
    property string monitorName: ""
    // The toast payload (notifications.js). A new payload while the toast shows (a replace, a
    // stack join) crossfades the content in place; M-06 is not replayed (notch.md §6 rule 3).
    property var payload: ({})

    // The bulge size: 420 × 72 / 104 / 132 (notch.md §6); while the reply field is open it takes
    // the button row's place and the toast grows by the difference.
    readonly property real bulgeWidth: Tokens.surfaces.toast.width
    readonly property real bulgeHeight: NJ.toastHeight(payload, Tokens.surfaces.toast.heights)
        + (replying ? Math.max(0, replyField.height - actions.height) : 0)
    readonly property bool hovered: hover.hovered
    // The inline reply field is open (takes the keyboard; the countdown stops).
    property bool replying: false

    // The body or a button was clicked: the action id ("" = the default action).
    signal activated(string action)
    // ✕ or middle click.
    signal dismissed()
    signal replied(string text)
    // A right click at a point in this item's coordinates.
    signal rightClicked(real x, real y)

    // M-06 entrance progress of the icon, title and body (0 → 1).
    property real _icon: 1
    property real _title: 1
    property real _body: 1

    // Open the inline reply field (the reply action) and give it the keyboard.
    function openReply(): void {
        replying = true;
        replyField.forceFocus();
    }
    // Close the reply field (Esc in the field returns to the toast; the field has the keyboard
    // through Notch.wantsKeyboard, not the shell's Esc ladder).
    function closeReply(): bool {
        if (!replying) return false;
        replying = false;
        replyField.clear();
        return true;
    }

    // Found by the probe (phase 5):
    // The toast's tokens, the stack record (null for a single toast) and the buttons (the
    // actions, plus Reply when the sender allows it).
    readonly property var _t: Tokens.surfaces.toast
    // Found in review: the payload on screen (follows `payload` through the in-place crossfade)
    // and the crossfade's content opacity.
    property var _p: ({})
    property real _swap: 1
    property bool _ready: false
    onPayloadChanged: {
        if (!_ready) return;
        if (Motion.reduced) _p = payload;
        else swapAnim.restart();
    }
    readonly property var _stack: _p.stack || null
    readonly property var _actions: (_p.actions || []).concat(_p.reply ? [{ id: "__reply", text: "Reply" }] : [])

    Component.onCompleted: {
        _p = payload;
        _ready = true;
        if (!Motion.reduced) entranceAnim.start();
    }

    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.MiddleButton) root.dismissed();
            else if (m.button === Qt.RightButton) root.rightClicked(m.x, m.y);
            else root.activated("");
        }
    }
    // the app icon, the glyph of a system toast, or the stack's overlapping icons
    Item {
        id: iconBox
        x: Tokens.padToast
        y: Tokens.padToast
        width: root._t.iconSize
        height: width
        scale: (Motion.reduced ? 1 : Motion.catalogueValue("toast.iconScaleFrom")) + (1 - (Motion.reduced ? 1 : Motion.catalogueValue("toast.iconScaleFrom"))) * root._icon
        opacity: root._icon * root._swap
        AppIcon {
            anchors.fill: parent
            visible: !root._stack && !root._p.glyph
            size: parent.width
            icon: root._p.appIcon || ""
            name: root._p.appName || ""
        }
        Glyph {
            anchors.centerIn: parent
            visible: !root._stack && !!root._p.glyph
            name: root._p.glyph || ""
            size: Tokens.glyphToast
            colour: root._p.critical ? Tokens.crit : Tokens.inkMain
        }
        Repeater {
            model: root._stack ? root._stack.icons : []
            delegate: AppIcon {
                required property string modelData
                required property int index
                x: index * Tokens.s3
                y: index * Tokens.s1
                z: -index
                size: root._t.iconSize - 2 * Tokens.s2
                icon: modelData
            }
        }
    }
    Column {
        id: texts
        x: iconBox.x + iconBox.width + Tokens.gapToastIcon
        y: Tokens.padToast - Tokens.s1
        width: root.width - x - Tokens.padToast - (image.visible ? image.width + Tokens.gapToastIcon : 0)
        spacing: Tokens.s1
        opacity: root._swap
        Label {
            width: parent.width - closeButton.width
            type: "micro"
            ink: "meta"
            elide: Text.ElideRight
            text: [root._p.appName || "", root._p.time ? F.ago(root._p.time, Date.now()) : ""].filter(s => s !== "").join(" · ")
        }
        Row {
            width: parent.width
            spacing: Tokens.s2
            opacity: root._title
            transform: Translate { y: Motion.catalogueValue("toast.textRise") * (1 - root._title) }
            Glyph {
                visible: !!root._p.critical && (root._p.nid || 0) !== 0
                anchors.verticalCenter: parent.verticalCenter
                name: "warning"
                size: Tokens.glyphRow
                colour: Tokens.crit
            }
            Label {
                width: parent.width - x
                type: "bodyStrong"
                elide: Text.ElideRight
                text: root._p.summary || ""
            }
        }
        Label {
            width: parent.width
            visible: text !== ""
            opacity: root._body
            transform: Translate { y: Motion.catalogueValue("toast.textRise") * (1 - root._body) }
            type: "body"
            ink: "sec"
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            // with a button row only one line fits the 104 / 132 heights
            maximumLineCount: root._actions.length > 0 ? 1 : root._t.bodyMaxLines
            elide: Text.ElideRight
            text: root._p.body || ""
            onLinkActivated: link => Qt.openUrlExternally(link)
        }
    }
    Thumb {
        id: image
        visible: String(root._p.image || "") !== ""
        x: root.width - Tokens.padToast - width
        y: Tokens.padToast
        width: root._t.imageSize
        height: width
        radius: root._t.imageRadius
        opacity: root._swap
        source: root._p.image || ""
    }
    IconButton {
        id: closeButton
        x: root.width - Tokens.s1 - width
        y: Tokens.s1
        size: "bar"
        glyph: "close"
        tooltip: "Dismiss"
        opacity: root.hovered ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { StandardAnimation { duration: Motion.ms("hover", false) } }
        onClicked: root.dismissed()
    }
    Row {
        id: actions
        visible: root._actions.length > 0 && !root.replying
        opacity: root._swap
        x: texts.x
        y: NJ.toastHeight(root._p, root._t.heights) - Tokens.padToast - height
        spacing: Tokens.s2
        Repeater {
            model: root._actions
            delegate: Button {
                required property var modelData
                text: modelData.text
                variant: "quiet"
                onClicked: {
                    if (modelData.id === "__reply") root.openReply();
                    else root.activated(modelData.id);
                }
            }
        }
    }
    Field {
        id: replyField
        visible: root.replying
        x: texts.x
        width: root.width - x - Tokens.padToast
        y: actions.y
        placeholder: "Reply"
        glyph: "reply"
        onAccepted: {
            const t = text;
            root.closeReply();
            if (t.trim() !== "") root.replied(t);
        }
        Keys.onEscapePressed: root.closeReply()
    }
    // The in-place crossfade: the old content out over morphOutMs, then the new one in (`fade`).
    SequentialAnimation {
        id: swapAnim
        StandardAnimation { target: root; property: "_swap"; to: 0; duration: Tokens.surfaces.notch.morphOutMs }
        ScriptAction { script: root._p = root.payload }
        StandardAnimation { target: root; property: "_swap"; to: 1; duration: Motion.ms("fade", false) }
    }
    SequentialAnimation {
        id: entranceAnim
        PropertyAction { target: root; properties: "_icon,_title,_body"; value: 0 }
        ParallelAnimation {
            StandardAnimation { target: root; property: "_icon"; to: 1; duration: Motion.ms("small", false) }
            SequentialAnimation {
                PauseAnimation { duration: Motion.catalogueMs("toast.coveGrow", false) }
                StandardAnimation { target: root; property: "_title"; to: 1; duration: Motion.ms("fade", false) }
            }
            SequentialAnimation {
                PauseAnimation { duration: Motion.catalogueMs("toast.coveGrow", false) + Motion.catalogueMs("toast.textStagger", false) }
                StandardAnimation { target: root; property: "_body"; to: 1; duration: Motion.ms("fade", false) }
            }
        }
    }
}
