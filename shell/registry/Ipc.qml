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
    function serviceSummary(): var {
        return {
            config: { loaded: Config.loaded, fileError: Config.fileError, v1File: Config.v1File },
            tokens: { mode: Tokens.mode, palette: Tokens.palette, accent: Tokens.accentName, glass: Tokens.glass },
            hypr: { focusedMonitor: Hypr.focusedMonitor, monitors: Hypr.monitors.map(m => m.name),
                    windows: Hypr.windows.length, submap: Hypr.submap },
            wallpaper: { monitors: Hypr.monitors.map(m => ({ name: m.name, path: Wallpaper.pathFor(m.name) })),
                         images: Wallpaper.images.length },
            session: { locked: Session.locked, canLock: Session.canLock }
        };
    }
    // The answer of a service's IPC functions until its stage fills it (07 §7: never an empty answer).
    function notYet(name: string): string { return "error: " + name + " is not available yet"; }
    // Parse an optional JSON argument ("" → {}); null when invalid.
    function parseArgs(json: string): var {
        if (json === undefined || json === null || json === "" || json === "undefined") return {};
        try {
            const v = JSON.parse(json);
            return v !== null && typeof v === "object" && !Array.isArray(v) ? v : null;
        } catch (e) {
            return null;
        }
    }

    IpcHandler {
        target: "shell"
        function state(): string {
            const s = JSON.parse(SurfaceManager.state());
            s.services = root.serviceSummary();
            return JSON.stringify(s);
        }
        function restart(): string {
            restartTouch.running = true;
            return "ok";
        }
        function reloadConfig(): string { Config.reload(); return "ok"; }
        function log(level: string): string { return Log.setLevel(level) ? "ok" : "error: level is debug, info, warn or error"; }
    }

    IpcHandler {
        target: "surface"
        function open(name: string, args: string): string {
            const a = root.parseArgs(args);
            if (a === null) return "error: args must be a JSON object";
            return SurfaceManager.open(name, a) ? "ok" : "error: " + name + " not opened (locked, behind polkit, or unknown)";
        }
        function close(name: string): string { SurfaceManager.close(name); return "ok"; }
        function toggle(name: string): string { return SurfaceManager.toggle(name) ? "open" : "closed"; }
        function back(): string { SurfaceManager.back(); return "ok"; }
    }

    IpcHandler {
        target: "spotlight"
        function open(query: string, scope: string): string {
            return SurfaceManager.open("spotlight", { query: query || "", scope: scope || "" }) ? "ok" : "error: spotlight not opened";
        }
    }

    IpcHandler {
        target: "notch"
        function event(text: string, glyph: string): string {
            if (!text) return "error: text missing";
            return SurfaceManager.post("event", { text: text, glyph: glyph || "info" }) > 0 ? "ok" : "error: event dropped";
        }
        function toast(json: string): string {
            const a = root.parseArgs(json);
            if (a === null) return "error: toast must be a JSON object";
            if (!Notifications.available) return root.notYet("notifications");
            Notifications.inject(a);
            return "ok";
        }
    }

    IpcHandler {
        target: "theme"
        function mode(value: string): string {
            if (value !== "toggle" && ["dark", "light", "auto"].indexOf(value) < 0) return "error: mode is dark, light, auto or toggle";
            const why = value === "toggle" ? Theme.toggleMode() : Theme.setMode(value);
            return why ? "error: " + why : "ok";
        }
        function accent(name: string): string {
            const e = Config.entry("appearance.accent");
            if (!e || e.values.indexOf(name) < 0) return "error: accent is one of " + (e ? e.values.join(", ") : "");
            const why = Theme.setAccent(name);
            return why ? "error: " + why : "ok";
        }
        function glass(value: string): string {
            if (value !== "on" && value !== "off") return "error: glass is on or off";
            const why = Theme.setGlass(value === "on");
            return why ? "error: " + why : "ok";
        }
    }

    IpcHandler {
        target: "wallpaper"
        function set(path: string, monitor: string): string {
            if (!path) return "error: path missing";
            if (!Paths.insideHome(path)) return "error: the image must be inside your home folder";
            Wallpaper.set(path, monitor || "");
            return "ok";
        }
        function next(): string { Wallpaper.next(); return "ok"; }
    }

    IpcHandler {
        target: "focus"
        function start(minutes: string, intent: string): string {
            if (!Focus.available) return root.notYet("focus");
            const m = parseInt(minutes);
            if (!(m >= 1 && m <= 600)) return "error: minutes must be 1–600";
            Focus.start(m, intent || null);
            return "ok";
        }
        function stop(): string { if (!Focus.available) return root.notYet("focus"); Focus.stop(); return "ok"; }
        function pause(): string { if (!Focus.available) return root.notYet("focus"); Focus.pause(); return "ok"; }
        function resume(): string { if (!Focus.available) return root.notYet("focus"); Focus.resume(); return "ok"; }
        function extend(minutes: string): string {
            if (!Focus.available) return root.notYet("focus");
            const m = parseInt(minutes);
            if (!(m >= 1 && m <= 240)) return "error: minutes must be 1–240";
            Focus.extend(m);
            return "ok";
        }
    }

    IpcHandler {
        target: "dnd"
        function on(): string { if (!Dnd.available) return root.notYet("dnd"); Dnd.turnOn(); return "ok"; }
        function off(): string { if (!Dnd.available) return root.notYet("dnd"); Dnd.turnOff(); return "ok"; }
        // `aptus msg dnd for <duration>`: "for" is reserved in JavaScript, so aptus msg maps it to
        // forDuration. Duration: "90m", "1h", "1h30m", "45" (minutes).
        function forDuration(duration: string): string {
            if (!Dnd.available) return root.notYet("dnd");
            const m = /^(?:(\d+)h)?(?:(\d+)m?)?$/.exec(String(duration).trim());
            const secs = m && (m[1] || m[2]) ? (parseInt(m[1] || "0") * 60 + parseInt(m[2] || "0")) * 60 : 0;
            if (secs <= 0) return "error: duration like 90m, 1h, 1h30m or 45";
            Dnd.forSeconds(secs);
            return "ok";
        }
        function until(hhmm: string): string {
            if (!Dnd.available) return root.notYet("dnd");
            if (!/^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(hhmm)) return "error: time like 07:30";
            Dnd.untilTime(hhmm);
            return "ok";
        }
    }

    IpcHandler {
        target: "capture"
        function region(): string { if (!Capture.available) return root.notYet("capture"); Capture.region(); return "ok"; }
        function screen(): string { if (!Capture.available) return root.notYet("capture"); Capture.screen(); return "ok"; }
        function window(): string { if (!Capture.available) return root.notYet("capture"); Capture.window(); return "ok"; }
        function record(): string { if (!Capture.available) return root.notYet("capture"); Capture.record(); return "ok"; }
        function stop(): string { if (!Capture.available) return root.notYet("capture"); Capture.stop(); return "ok"; }
        function colour(): string { if (!Capture.available) return root.notYet("capture"); Capture.colour(); return "ok"; }
    }

    IpcHandler {
        target: "session"
        // Answers "error: …" whenever the shell cannot lock right now (before S6, or Session fails),
        // so `aptus msg session lock || hyprlock …` falls back (phase-1 decision 9).
        function lock(): string {
            if (!Session.canLock) return "error: no lock screen yet";
            try { Session.lock(); } catch (e) { return "error: " + e; }
            return "ok";
        }
        function logout(): string { Session.logout(); return "ok"; }
        function reboot(): string {
            if (!Session.canPower) return root.notYet("reboot");
            Session.reboot();
            return "ok";
        }
        function poweroff(): string {
            if (!Session.canPower) return root.notYet("poweroff");
            Session.poweroff();
            return "ok";
        }
        function sheet(): string { return SurfaceManager.toggle("session") ? "open" : "closed"; }
    }

    IpcHandler {
        target: "jot"
        function add(text: string): string { if (!Jot.available) return root.notYet("jot"); if (!text) return "error: text missing"; Jot.add(text); return "ok"; }
        function todo(text: string): string { if (!Jot.available) return root.notYet("jot"); if (!text) return "error: text missing"; Jot.todo(text); return "ok"; }
    }

    IpcHandler {
        target: "settings"
        function open(pageOrKey: string): string {
            const a = !pageOrKey ? {} : (Config.entry(pageOrKey) ? { key: pageOrKey } : { page: pageOrKey });
            return SurfaceManager.open("settings", a) ? "ok" : "error: settings not opened";
        }
    }

    // `shell restart`: the restart flag makes the supervisor start the shell again at once (07 §10).
    Process {
        id: restartTouch
        command: ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && touch \"$1\"", "sh", Paths.restartFlag]
        onRunningChanged: if (!running) Qt.callLater(Qt.quit)
    }
}
