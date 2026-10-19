pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history on top of cliphist. The user's autostart runs `wl-paste --watch cliphist store`; this
// singleton only reads the history and puts an entry back. Without cliphist `available` stays false and the
// launcher shows a short hint.
Singleton {
    id: root

    property var entries: []         // { id, kind: "text" | "image", preview }, newest first
    property bool available          // cliphist found in PATH

    Process {
        command: ["sh", "-c", "command -v cliphist"]
        running: true
        // The exit status enum of Process is not known to qmllint.
        // qmllint disable signal-handler-parameters
        onExited: code => {
            root.available = code === 0
            if (root.available) root.refresh()
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.entries = root.parse(text)
        }
    }

    // Changes (delete, wipe) run here and re-read the list when done.
    Process {
        id: change
        // qmllint disable signal-handler-parameters
        onExited: root.refresh()
        // qmllint enable signal-handler-parameters
    }

    // `cliphist list` prints "<id>\t<preview>"; binary entries have a preview like "[[ binary data 12 KiB png 800x600 ]]".
    function parse(text: string): var {
        const out = []
        for (const line of text.split("\n")) {
            const tab = line.indexOf("\t")
            if (tab <= 0) continue
            const preview = line.slice(tab + 1).trim()
            const bin = preview.match(/^\[\[ binary data (.*) \]\]$/)
            out.push({ id: line.slice(0, tab), kind: bin ? "image" : "text", preview: bin ? "Image, " + bin[1] : preview })
        }
        return out
    }

    function refresh(): void {
        if (!available || list.running) return
        list.running = true
    }

    function copy(entryId: string): void {
        if (!entryId) throw new Error("invariant: Clipboard.copy: empty entry id")
        if (!available) throw new Error("invariant: Clipboard.copy: cliphist is not available")
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", entryId])
    }

    function remove(entryId: string): void {
        if (!entryId) throw new Error("invariant: Clipboard.remove: empty entry id")
        if (!available) throw new Error("invariant: Clipboard.remove: cliphist is not available")
        change.command = ["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist delete", "sh", entryId]
        change.running = true
    }

    function clear(): void {
        if (!available) throw new Error("invariant: Clipboard.clear: cliphist is not available")
        change.command = ["cliphist", "wipe"]
        change.running = true
    }
}
