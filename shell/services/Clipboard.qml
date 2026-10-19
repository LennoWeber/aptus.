pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history on top of cliphist. The user's autostart already runs `wl-paste --watch cliphist store`,
// but cliphist is not installed yet: the installer provides it (Fedora package if there is one, else a release
// binary after asking). Without cliphist `available` stays false and the mode shows a short hint.
// Signatures only. Bodies come in phase 7.
Singleton {
    property var entries             // list of ClipboardEntry, newest first
    property bool available          // cliphist found in PATH

    Process {
        id: list
        running: false
        // TODO(phase 7): `cliphist list` -> entries; `cliphist decode <id> | wl-copy` for copy; image thumbnails via a temp file.
    }

    function refresh(): void {
        // TODO(phase 7): read cliphist, build ClipboardEntry items newest first, thumbnails for images.
        throw new Error("not implemented")
    }

    function copy(entryId: string): void {
        if (!entryId) throw new Error("invariant: Clipboard.copy: empty entry id")
        if (!available) throw new Error("invariant: Clipboard.copy: cliphist is not available")
        throw new Error("not implemented")
    }

    function remove(entryId: string): void {
        if (!entryId) throw new Error("invariant: Clipboard.remove: empty entry id")
        if (!available) throw new Error("invariant: Clipboard.remove: cliphist is not available")
        throw new Error("not implemented")
    }

    function pin(entryId: string): void {
        if (!entryId) throw new Error("invariant: Clipboard.pin: empty entry id")
        if (!available) throw new Error("invariant: Clipboard.pin: cliphist is not available")
        throw new Error("not implemented")
    }

    function clear(): void {
        if (!available) throw new Error("invariant: Clipboard.clear: cliphist is not available")
        throw new Error("not implemented")
    }
}
