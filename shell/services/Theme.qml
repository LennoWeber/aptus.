pragma Singleton
pragma ComponentBehavior: Bound
// Theme: mode, accent, glass, auto schedule, render requests.
// Owner: S1 (mode, accent, glass via Config), S2 (aptus-theme apply, the auto schedule).
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // JSON summary of the last aptus-theme apply (S2; lib/aptus/theme/apply.py Report)
    property string lastApply: ""
    property bool applying: false
    // Target id → why, from the last apply's "failed" (the shell toasts only these).
    property var failed: ({})
    // The theme generation the last apply produced (0: none yet).
    property int generation: 0
    // The resolve inputs of the last request, as JSON (lib/aptus/theme/inputs.py Inputs).
    property string _pendingInputs: ""
    // A request arrived while a run was going: run once more after it.
    property bool _queued: false
    // A render of the shell's own is waiting or running (Tokens ignores resolved.json meanwhile).
    readonly property bool busy: applying || _queued || applyTimer.running

    // S1: each setter writes Config (appearance.*), which re-resolves Tokens; S2 adds aptus-theme
    // apply on top (the app slots of 08 §5). Each returns "" or why Config refused the value.
    // appearance.mode: "dark" | "light" | "auto".
    function setMode(mode: string): string { return _set("appearance.mode", mode); }
    // Light ↔ dark, always explicit (Super+T): from `auto` it leaves auto for the opposite of now.
    function toggleMode(): string { return _set("appearance.mode", Tokens.mode === "dark" ? "light" : "dark"); }
    // appearance.accent: one of the six or "wallpaper".
    function setAccent(name: string): string { return _set("appearance.accent", name); }
    function setGlass(on: bool): string { return _set("appearance.glass", on); }

    // Ask for an `aptus-theme apply` with the current resolution: debounced 250 ms, started after
    // the shell's own crossfade (08 §6), one run at a time (a request during a run runs after it).
    function requestApply(): void {
        applyTimer.restart();
    }
    // The --inputs JSON for aptus-theme (lib/aptus/theme/inputs.py to_dict) from Tokens and Config.
    function _inputs(): var {
        return {
            mode: Tokens.mode,
            accent: String(Config.get("appearance.accent")),
            contrast: String(Config.get("appearance.contrast")),
            glass: Boolean(Config.get("appearance.glass")),
            modeSetting: String(Config.get("appearance.mode")),
            wallpaperHue: Tokens.wallpaperHue,
            wallpaperChroma: Tokens.wallpaperChroma,
            wallpaperLightness: Tokens.wallpaperLightness,
            currentAccent: Tokens.accentName,
            frameEdge: Math.round(Number(Config.get("frame.edge"))),
            reduceMotion: Motion.reduced,
            bakeTargets: (Config.get("isolation.bakeTargets") || []).map(String)
        };
    }
    // Parse the JSON report on stdout into lastApply, failed and generation; warn for failures.
    function _applied(stdout: string, stderr: string, exitCode: int): void {
        let report = null;
        try { report = JSON.parse(stdout); } catch (e) { report = null; }
        if (report === null || typeof report !== "object") {
            const why = stderr.trim() || "aptus-theme apply exited " + exitCode;
            lastApply = "";
            failed = { render: why };
            Log.warn("service.theme", "apply failed: " + why);
            return;
        }
        lastApply = stdout.trim();
        failed = report.failed || {};
        generation = report.generation || 0;
        for (const id in failed)
            Log.warn("service.theme", id + ": " + failed[id]);
        Log.info("service.theme", "generation " + generation + " (" + (report.mode || "?") + ")"
                 + (report.unchanged ? ", unchanged" : ""));
    }
    function _run(): void {
        if (applying) {
            _queued = true;
            return;
        }
        _queued = false;
        _pendingInputs = JSON.stringify(_inputs());
        applying = true;
        proc.command = [Paths.bin + "/aptus-theme", "apply", "--inputs", _pendingInputs];
        proc.start();
    }

    function _set(key: string, value: var): string {
        const why = Config.set(key, value);
        if (why) Log.warn("service.theme", key + " = " + JSON.stringify(value) + " refused: " + why);
        else Log.info("service.theme", key + " = " + JSON.stringify(value));
        return why;
    }

    Timer {
        id: applyTimer
        interval: 250 + Tokens._themeMs
        onTriggered: root._run()
    }
    Run {
        id: proc
        onFinished: (stdout, stderr, code) => root._finish(stdout, code < 0 ? "aptus-theme could not be started" : stderr, code)
    }
    function _finish(stdout: string, stderr: string, exitCode: int): void {
        applying = false;
        _applied(stdout, stderr, exitCode);
        if (_queued) _run();
    }
    // What changes the apps' paint: the shell's own resolution (Tokens.resolved; not one an
    // outside render brought: the apps carry it already, and an apply now would send Config's
    // values back), and the settings that shape Own files and bakes.
    Connections {
        target: Tokens
        function onResolved(): void { root.requestApply(); }
    }
    Connections {
        target: Config
        function onSettingChanged(key: string): void {
            if (["frame.edge", "motion.reduce", "isolation.bakeTargets"].indexOf(key) >= 0)
                root.requestApply();
        }
    }
}
