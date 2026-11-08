pragma Singleton
import QtQuick
// Test double of qs.core Config for tst_components (qmltestrunner cannot load Quickshell).
QtObject {
    property bool loaded: true
    property var values: ({ "appearance.textScale": 1, "frame.edge": 6, "bar.height": 32, "appearance.mode": "dark",
        "appearance.accent": "jade", "appearance.contrast": "normal", "appearance.glass": false, "weather.location": null,
        "motion.reduce": "off", "notch.overFullscreen": "critical" })
    signal settingChanged(string key)
    function get(key: string): var { return values[key]; }
}
