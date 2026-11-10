// Every IpcHandler of 07-architecture §7, called by `aptus msg <target> <function> [args…]`
// (qs ipc call). Optional arguments arrive as "" (aptus msg pads them). Functions return a short
// text answer ("ok", JSON, or "error: …").
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.services
import "../core/js/config.js" as ConfigLib

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
            session: { locked: Session.locked, canLock: Session.canLock },
            // S3: levels, the notification server and history (counts only: no bodies, 07 §11),
            // media, privacy and the bar's strips (the e2e tests assert on them)
            audio: { available: Audio.available, testDouble: Audio.testDouble, volume: Audio.volume, muted: Audio.muted,
                     micMuted: Audio.micMuted },
            brightness: { available: Brightness.available, hasBacklight: Brightness.hasBacklight,
                          brightness: Brightness.brightness, device: Brightness.device, kbdLevel: Brightness.kbdLevel,
                          kbdMax: Brightness.kbdMax },
            notifications: { available: Notifications.available, serverActive: Notifications.serverActive,
                             history: Notifications.history.length, unread: Notifications.unread, held: Notifications.held },
            media: { players: Media.players.length, active: Media.active ? Media.active.dbusName : "" },
            privacy: { mic: Privacy.mic.length, camera: Privacy.camera.length, screencast: Privacy.screencast },
            bar: { strips: Hypr.monitors.reduce((o, m) => { o[m.name] = Hypr.stripFor(m.name).pills.map(p => p.id); return o; }, {}) }
        };
    }
    // The answer of a service's IPC functions until its stage fills it (07 §7: never an empty answer).
    function notYet(name: string): string { return "error: " + name + " is not available yet"; }
    // Run fn() when the service is built (`available`, else notYet); fn may return an "error: …"
    // text (a bad argument), which is the answer; anything else answers "ok".
    function guarded(service: var, name: string, fn: var): string {
        if (!service.available) return notYet(name);
        const why = fn();
        return typeof why === "string" && why.indexOf("error:") === 0 ? why : "ok";
    }
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
            restartFlag.setText("restart\n");
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
            return root.guarded(Notifications, "notifications", () => Notifications.inject(a));
        }
    }

    IpcHandler {
        target: "theme"
        function mode(value: string): string {
            const modes = Config.entry("appearance.mode").values;
            if (value !== "toggle" && modes.indexOf(value) < 0) return "error: mode is " + modes.join(", ") + " or toggle";
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
            return root.guarded(Focus, "focus", () => {
                const m = parseInt(minutes);
                if (!(m >= 1 && m <= 600)) return "error: minutes must be 1–600";
                Focus.start(m, intent || null);
            });
        }
        function stop(): string { return root.guarded(Focus, "focus", () => Focus.stop()); }
        function pause(): string { return root.guarded(Focus, "focus", () => Focus.pause()); }
        function resume(): string { return root.guarded(Focus, "focus", () => Focus.resume()); }
        function extend(minutes: string): string {
            return root.guarded(Focus, "focus", () => {
                const m = parseInt(minutes);
                if (!(m >= 1 && m <= 240)) return "error: minutes must be 1–240";
                Focus.extend(m);
            });
        }
    }

    IpcHandler {
        target: "dnd"
        function on(): string { return root.guarded(Dnd, "dnd", () => Dnd.turnOn()); }
        function off(): string { return root.guarded(Dnd, "dnd", () => Dnd.turnOff()); }
        // `aptus msg dnd for <duration>`: "for" is reserved in JavaScript, so aptus msg maps it to
        // forDuration. Duration: "90m", "1h", "1h30m", "45" (minutes).
        function forDuration(duration: string): string {
            return root.guarded(Dnd, "dnd", () => {
                const m = /^(?:(\d+)h)?(?:(\d+)m?)?$/.exec(String(duration).trim());
                const secs = m && (m[1] || m[2]) ? (parseInt(m[1] || "0") * 60 + parseInt(m[2] || "0")) * 60 : 0;
                if (secs <= 0) return "error: duration like 90m, 1h, 1h30m or 45";
                Dnd.forSeconds(secs);
            });
        }
        function until(hhmm: string): string {
            return root.guarded(Dnd, "dnd", () => {
                if (!ConfigLib.TIME_RE.test(hhmm)) return "error: time like 07:30";
                Dnd.untilTime(hhmm);
            });
        }
    }

    IpcHandler {
        target: "capture"
        function region(): string { return root.guarded(Capture, "capture", () => Capture.region()); }
        function screen(): string { return root.guarded(Capture, "capture", () => Capture.screen()); }
        function window(): string { return root.guarded(Capture, "capture", () => Capture.window()); }
        function record(): string { return root.guarded(Capture, "capture", () => Capture.record()); }
        function stop(): string { return root.guarded(Capture, "capture", () => Capture.stop()); }
        function colour(): string { return root.guarded(Capture, "capture", () => Capture.colour()); }
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
        function add(text: string): string { return root.guarded(Jot, "jot", () => text ? Jot.add(text) : "error: text missing"); }
        function todo(text: string): string { return root.guarded(Jot, "jot", () => text ? Jot.todo(text) : "error: text missing"); }
    }

    IpcHandler {
        target: "settings"
        function open(pageOrKey: string): string {
            const a = !pageOrKey ? {} : (Config.entry(pageOrKey) ? { key: pageOrKey } : { page: pageOrKey });
            return SurfaceManager.open("settings", a) ? "ok" : "error: settings not opened";
        }
    }

    // `shell restart`: the restart flag makes the supervisor start the shell again at once (07 §10).
    // The shell quits only once the flag is written: an exit 0 without it ends the supervisor.
    FileView {
        id: restartFlag
        path: Paths.restartFlag
        printErrors: false
        onSaved: Qt.callLater(Qt.quit)
        onSaveFailed: error => Log.error("ipc", "shell restart: the restart flag could not be written ("
                                         + FileViewError.toString(error) + "); the shell keeps running")
    }
}
