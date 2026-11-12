// The layout OSD after a shell start (wave-2 review of S3, finding 3): Hypr reads every keyboard's
// layout at start (`hyprctl -j devices`), so the first switch per keyboard shows the OSD and the
// start itself shows none. Hypr.qml is a Quickshell Singleton: the test loads its text as an Item
// (as tst_theme does) with Quickshell.Hyprland, Apps and Paths replaced by the doubles below.
import QtQuick
import QtTest
import qs.core
import "../../shell/services/js/hypr.js" as H

TestCase {
    id: testCase
    name: "hyprlayouts"

    // Quickshell.Hyprland's singleton as far as Hypr reads it at start: no monitors, workspaces
    // or windows, no events.
    QtObject {
        id: fakeHyprland
        property var focusedMonitor: null
        property var activeToplevel: null
        readonly property QtObject monitors: QtObject { property var values: [] }
        readonly property QtObject workspaces: QtObject { property var values: [] }
        readonly property QtObject toplevels: QtObject { property var values: [] }
        signal rawEvent(var event)
        function dispatch(request: string): void {}
        function refreshMonitors(): void {}
        function refreshWorkspaces(): void {}
        function refreshToplevels(): void {}
    }
    readonly property var hyprland: fakeHyprland
    readonly property var apps: ({ idFor: cls => "", nameFor: cls => String(cls) })
    property var hypr: null
    property var proc: null

    readonly property string devices: JSON.stringify({
        mice: [],
        keyboards: [
            { address: "0x1", name: "at-translated-set-2-keyboard", layout: "us,de", active_keymap: "English (US)", main: true },
            { address: "0x2", name: "wtype", layout: "", active_keymap: "error", main: false },
            { address: "0x3", name: "usb-keyboard", layout: "de", active_keymap: "German", main: false }
        ]
    })

    function load(): var {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl("../../shell/services/Hypr.qml"), false);
        xhr.send();
        const text = xhr.responseText.replace("pragma Singleton\n", "").replace("import Quickshell\n", "")
            .replace("import Quickshell.Hyprland\n", "").replace(/\nSingleton \{/, "\nItem {")
            .replace(/import "js\//g, 'import "../../shell/services/js/')
            .replace("event: HyprlandEvent", "event: var")
            .replace('Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")', '""')
            .replace("model: Hyprland.toplevels", "model: []")
            .replace(/\bHyprland\b/g, "testCase.hyprland")
            .replace(/\bApps\./g, "testCase.apps.")
            .replace(/\bPaths\.workspacesState\b/g, '""');
        return Qt.createQmlObject(text, testCase, "Hypr.qml");
    }
    function init() {
        SurfaceManager.locked = false;
        SurfaceManager.syncMonitors(["A"]);
        SurfaceManager.activeMonitor = "A";
        hypr = load();
        proc = hypr.resources.find(o => o.command !== undefined && o.command[0] === "hyprctl") || null;
    }
    function cleanup() {
        hypr.destroy();
        hypr = proc = null;
        for (const e of SurfaceManager.monitors["A"].passive.slice()) SurfaceManager.dismiss(e.id, "A");
    }
    function layoutOsds(): var {
        return SurfaceManager.monitors["A"].passive.filter(e => e.kind === "osd" && e.payload.kind === "layout");
    }
    // hyprctl's answer (devicesProc is a Run).
    function answer(text: string): void {
        proc.finished(text, "", 0);
    }

    function test_devices_give_each_keyboards_layout() {
        compare(H.layoutsFromDevices(devices), { layouts: { "at-translated-set-2-keyboard": "English (US)", "usb-keyboard": "German" },
                                                 main: "English (US)" });
        compare(H.layoutsFromDevices("not json"), { layouts: {}, main: "" });
        compare(H.layoutsFromDevices('{"keyboards": [{"name": 3}]}'), { layouts: {}, main: "" });
    }

    function test_the_first_switch_after_a_start_shows_the_osd() {
        verify(proc !== null, "Hypr asks for the devices at start");
        compare(proc.command, ["hyprctl", "-j", "devices"]);
        verify(proc.running);
        answer(devices);
        compare(layoutOsds().length, 0, "the start shows none");
        compare(hypr.layout, "English (US)");
        hypr._onLayout("at-translated-set-2-keyboard,English (US)");       // the same layout: no change
        compare(layoutOsds().length, 0);
        hypr._onLayout("at-translated-set-2-keyboard,German");
        compare(layoutOsds().length, 1, "the first switch shows the OSD");
        compare(layoutOsds()[0].payload.value, "German");
        hypr._onLayout("wtype,English (US)");                               // another keyboard becoming active
        compare(layoutOsds()[0].payload.value, "German");
    }

    function test_an_event_before_the_answer_stays() {
        verify(proc !== null);
        hypr._onLayout("usb-keyboard,English (US)");                         // newer than the devices' answer
        answer(devices);
        hypr._onLayout("usb-keyboard,English (US)");
        compare(layoutOsds().length, 0);
        hypr._onLayout("usb-keyboard,German");
        compare(layoutOsds().length, 1);
    }
}
