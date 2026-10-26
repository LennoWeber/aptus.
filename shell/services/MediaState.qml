import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Media state (MPRIS).
Scope {
    id: root

    // The player that is playing, else the first one.
    readonly property var player: {
        const list = Array.from(Mpris.players.values)
        return list.find(p => p.isPlaying) || list[0] || null
    }

    property bool available: player !== null
    property bool playing: player ? player.isPlaying : false
    property string title: player ? player.trackTitle : ""
    property string artist: player ? player.trackArtist : ""
    property string album: player ? player.trackAlbum : ""
    property string artUrl: player ? player.trackArtUrl : ""
    property string playerName: player ? player.identity : ""
    property string desktopEntry: player && player.desktopEntry ? player.desktopEntry : ""   // desktop entry of the player ("spotify"), "" when it has none
    // Icon source of the player's app, "" when none is found. The desktop entries load a moment after the start: the binding reads them.
    property string appIcon: {
        const loaded = DesktopEntries.applications.values.length
        return loaded >= 0 ? iconFor(desktopEntry !== "" ? desktopEntry : playerName.toLowerCase()) : ""
    }
    property real positionSec: 0
    property real lengthSec: player && player.lengthSupported ? player.length : 0

    // MPRIS does not announce the position; ask once a second while playing.
    Timer {
        interval: 1000
        repeat: true
        running: root.playing
        triggeredOnStart: true
        onTriggered: {
            if (root.player && root.player.positionSupported) {
                root.player.positionChanged()
                root.positionSec = root.player.position
            }
        }
    }
    onPlayerChanged: positionSec = player && player.positionSupported ? player.position : 0

    // Icon source for a desktop entry ("spotify"), "" when the theme has none.
    function iconFor(entry: string): string {
        if (typeof entry !== "string") throw new Error("invariant: MediaState.iconFor: the entry must be a string")
        if (entry === "") return ""
        const direct = Quickshell.iconPath(entry, true)
        if (direct) return direct
        // The entry names a desktop file whose icon has another name ("spotify" -> "com.spotify.Client").
        const lower = entry.toLowerCase()
        const app = DesktopEntries.heuristicLookup(entry) || Array.from(DesktopEntries.applications.values).find(a => a.id.toLowerCase().indexOf(lower) >= 0)
        if (!app || !app.icon) return ""
        if (app.icon.startsWith("/")) return "file://" + app.icon
        return Quickshell.iconPath(app.icon, true) || ""
    }

    function playPause(): void {
        if (!available) throw new Error("invariant: MediaState.playPause: no media player")
        player.togglePlaying()
    }

    function play(): void {
        if (!available) throw new Error("invariant: MediaState.play: no media player")
        player.play()
    }

    function pause(): void {
        if (!available) throw new Error("invariant: MediaState.pause: no media player")
        player.pause()
    }

    function next(): void {
        if (!available) throw new Error("invariant: MediaState.next: no media player")
        player.next()
    }

    function previous(): void {
        if (!available) throw new Error("invariant: MediaState.previous: no media player")
        player.previous()
    }

    function seek(seconds: real): void {
        if (!available) throw new Error("invariant: MediaState.seek: no media player")
        if (!(seconds >= 0)) throw new Error("invariant: MediaState.seek: negative seek")
        if (lengthSec > 0 && seconds > lengthSec) throw new Error("invariant: MediaState.seek: seek beyond the end")
        if (player.canSeek) {
            player.position = seconds
            positionSec = seconds
        }
    }
}
