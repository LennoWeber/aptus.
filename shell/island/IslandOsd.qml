import QtQuick
import qs.models
import qs.theme
import qs.components

// The on-screen indicator in the island: a symbol, a bar (or a text) and the value.
Item {
    id: osdView

    property var osd                // { kind (Enums.OsdKind), level (0..1), muted, label } or null
    property color ink
    property color inkSoft
    property color line

    // Symbol name for an Enums.OsdKind (volume, sun, mic, cup, rotate).
    function glyphFor(kind: int): string {
        throw new Error("not implemented")
    }

    // The value as text: "42%", "Muted", or the label.
    function valueText(): string {
        throw new Error("not implemented")
    }
}
