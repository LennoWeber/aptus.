pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Search suggestions for the launcher's web mode. Off by default: while on, every line typed in web mode is sent
// to the search engine chosen in the settings (the one the search itself goes to).
Singleton {
    id: root

    property bool enabled                 // launcher.webSuggestions
    property string engineId: "google"    // browser.searchEngine
    property string forQuery              // the text the current suggestions belong to
    property var suggestions: []          // phrases for forQuery

    // Endpoints per known engine; other engines get no suggestions.
    readonly property var endpoints: ({
        google: "https://suggestqueries.google.com/complete/search?client=firefox&q=",
        duckduckgo: "https://duckduckgo.com/ac/?type=list&q=",
        bing: "https://api.bing.com/osjson.aspx?query="
    })
    readonly property bool supported: enabled && engineId in endpoints

    property string wanted                // the text last asked for

    // Ask for suggestions after a short pause in typing; an empty text clears them at once.
    function request(text: string): void {
        wanted = text
        if (!supported || text === "") {
            debounce.stop()
            clear()
            return
        }
        debounce.restart()
    }

    function clear(): void {
        if (suggestions.length > 0 || forQuery !== "") {
            suggestions = []
            forQuery = ""
        }
    }

    Timer {
        id: debounce
        interval: 150
        onTriggered: {
            fetch.running = false
            fetch.asked = root.wanted
            fetch.command = ["curl", "-fsS", "--max-time", "3", root.endpoints[root.engineId] + encodeURIComponent(root.wanted)]
            fetch.running = true
        }
    }

    Process {
        id: fetch
        property string asked
        stdout: StdioCollector {
            onStreamFinished: {
                // A newer request has been made meanwhile: this answer is stale.
                if (fetch.asked !== root.wanted) return
                root.forQuery = fetch.asked
                root.suggestions = root.parse(text)
            }
        }
    }

    // Google and Bing answer ["query", ["phrase", ...]]; DuckDuckGo with type=list answers the same.
    function parse(text: string): var {
        try {
            const data = JSON.parse(text)
            if (Array.isArray(data) && Array.isArray(data[1])) return data[1].filter(p => typeof p === "string" && p !== "").slice(0, 8)
        } catch (e) {
            // Not JSON (offline, blocked): no suggestions.
        }
        return []
    }
}
