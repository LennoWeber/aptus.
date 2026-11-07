// Every IpcHandler of 07-architecture §7, called by `aptus msg <target> <function> [args…]`
// (qs ipc call). Optional arguments arrive as "" (aptus msg pads them). Functions return a short
// text answer ("ok", JSON, or "error: …").
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.services

Scope {
    id: root

    // `aptus msg shell state` also lists service summaries; services add theirs here by name.
    function serviceSummary(): var { throw new Error("Ipc.serviceSummary: not implemented"); }
    // Parse an optional JSON argument ("" → {}); null when invalid.
    function parseArgs(json: string): var { throw new Error("Ipc.parseArgs: not implemented"); }

    IpcHandler {
        target: "shell"
        function state(): string { throw new Error("ipc shell.state: not implemented"); }
        function restart(): string { throw new Error("ipc shell.restart: not implemented"); }
        function reloadConfig(): string { throw new Error("ipc shell.reloadConfig: not implemented"); }
        function log(level: string): string { throw new Error("ipc shell.log: not implemented"); }
    }

    IpcHandler {
        target: "surface"
        function open(name: string, args: string): string { throw new Error("ipc surface.open: not implemented"); }
        function close(name: string): string { throw new Error("ipc surface.close: not implemented"); }
        function toggle(name: string): string { throw new Error("ipc surface.toggle: not implemented"); }
        function back(): string { throw new Error("ipc surface.back: not implemented"); }
    }

    IpcHandler {
        target: "spotlight"
        function open(query: string, scope: string): string { throw new Error("ipc spotlight.open: not implemented"); }
    }

    IpcHandler {
        target: "notch"
        function event(text: string, glyph: string): string { throw new Error("ipc notch.event: not implemented"); }
        function toast(json: string): string { throw new Error("ipc notch.toast: not implemented"); }
    }

    IpcHandler {
        target: "theme"
        function mode(value: string): string { throw new Error("ipc theme.mode: not implemented"); }
        function accent(name: string): string { throw new Error("ipc theme.accent: not implemented"); }
        function glass(value: string): string { throw new Error("ipc theme.glass: not implemented"); }
    }

    IpcHandler {
        target: "wallpaper"
        function set(path: string, monitor: string): string { throw new Error("ipc wallpaper.set: not implemented"); }
        function next(): string { throw new Error("ipc wallpaper.next: not implemented"); }
    }

    IpcHandler {
        target: "focus"
        function start(minutes: string, intent: string): string { throw new Error("ipc focus.start: not implemented"); }
        function stop(): string { throw new Error("ipc focus.stop: not implemented"); }
        function pause(): string { throw new Error("ipc focus.pause: not implemented"); }
        function resume(): string { throw new Error("ipc focus.resume: not implemented"); }
        function extend(minutes: string): string { throw new Error("ipc focus.extend: not implemented"); }
    }

    IpcHandler {
        target: "dnd"
        function on(): string { throw new Error("ipc dnd.on: not implemented"); }
        function off(): string { throw new Error("ipc dnd.off: not implemented"); }
        // `aptus msg dnd for <duration>`: "for" is reserved in JavaScript, so aptus msg maps it to
        // forDuration. Duration: "90m", "1h", "1h30m", "45" (minutes).
        function forDuration(duration: string): string { throw new Error("ipc dnd.forDuration: not implemented"); }
        function until(hhmm: string): string { throw new Error("ipc dnd.until: not implemented"); }
    }

    IpcHandler {
        target: "capture"
        function region(): string { throw new Error("ipc capture.region: not implemented"); }
        function screen(): string { throw new Error("ipc capture.screen: not implemented"); }
        function window(): string { throw new Error("ipc capture.window: not implemented"); }
        function record(): string { throw new Error("ipc capture.record: not implemented"); }
        function stop(): string { throw new Error("ipc capture.stop: not implemented"); }
        function colour(): string { throw new Error("ipc capture.colour: not implemented"); }
    }

    IpcHandler {
        target: "session"
        // Answers "error: …" whenever the shell cannot lock right now (before S6, or Session fails),
        // so `aptus msg session lock || hyprlock …` falls back (phase-1 decision 9).
        function lock(): string { throw new Error("ipc session.lock: not implemented"); }
        function logout(): string { throw new Error("ipc session.logout: not implemented"); }
        function reboot(): string { throw new Error("ipc session.reboot: not implemented"); }
        function poweroff(): string { throw new Error("ipc session.poweroff: not implemented"); }
        function sheet(): string { throw new Error("ipc session.sheet: not implemented"); }
    }

    IpcHandler {
        target: "jot"
        function add(text: string): string { throw new Error("ipc jot.add: not implemented"); }
        function todo(text: string): string { throw new Error("ipc jot.todo: not implemented"); }
    }

    IpcHandler {
        target: "settings"
        function open(pageOrKey: string): string { throw new Error("ipc settings.open: not implemented"); }
    }
}
