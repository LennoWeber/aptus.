// One content layer inside the notch's bulge (surfaces/notch.md §10): when the notch changes from
// one content to another the geometry retargets its spring while the old layer fades out over
// 110 ms and the new one fades in from 60 ms. Holds a toast, OSD, event, card or mode.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core

Item {
    id: root

    // The layer record (notch.js): { uid, kind, key, entryId, activity, mode, leaving }.
    property var record: ({})
    // False once a newer layer replaced this one: it fades out, then the Notch drops it.
    property bool shown: true
    // A plain crossfade (an in-place update such as replaces_id, or reduced motion): no entrance
    // choreography of the content.
    property bool plain: false

    // The size the content wants for the bulge.
    // TODO(phase): the content's bulgeWidth/bulgeHeight (notch.js bulgeSize).
    readonly property real bulgeWidth: 0
    readonly property real bulgeHeight: 0
    // The fade-out has finished (the Notch removes the layer).
    // TODO(phase): faded out completely after leaving (morphOutMs) → Notch._layerGone.
    readonly property bool gone: false
    // The loaded content item.
    // TODO(phase): the Loader's item.
    readonly property Item content: null

    // TODO(phase): a Loader of Toast / Osd / EventLine / ActivityCard / the mode component by
    //   record.kind; opacity in after morphInDelayMs (content rise 8), out in morphOutMs; `plain`
    //   swaps in place without the rise (replaces_id, M-06 not replayed).
}
