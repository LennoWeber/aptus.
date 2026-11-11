// The OSD's device name (surfaces/notch.md §8: it replaces the value for 1 s on a device change;
// wave-2 review of S3, finding 1). NotchLayer.qml creates the Osd behind a Loader with its payload
// bound at creation: the first payload's device shows (the change handler runs for the binding's
// first value), and it stays its whole second although the next press brings no device.
import QtQuick
import QtTest
import qs.core
import "../../shell/surfaces/notch" as Notch

TestCase {
    id: testCase
    name: "osd"

    property var payload: ({})
    // As NotchLayer.qml has it: `Component { id: osdComponent; Osd { payload: root.payload } }`
    // loaded by a Loader when an OSD entry comes.
    Component {
        id: hostComponent
        Loader {
            sourceComponent: Component { Notch.Osd { payload: testCase.payload } }
        }
    }

    function volume(level: int, device: string): var {
        return { kind: "volume", glyph: "volume_up", ink: "main", level: level, max: 100, dots: -1, steps: 0,
                 value: String(level), device: device };
    }
    // The value label's text (the OSD's only Label of type "body").
    function valueText(osd: Item): string {
        let found = null;
        const walk = it => {
            for (const c of it.children) {
                if (c.type === "body" && c.tabular !== undefined) found = c;
                walk(c);
            }
        };
        walk(osd);
        verify(found !== null, "the value label");
        return found.text;
    }

    function test_device_name_shows_for_the_first_payload() {
        payload = volume(45, "Headphones");
        const host = createTemporaryObject(hostComponent, testCase);
        tryVerify(() => host.item !== null);
        const osd = host.item;
        compare(valueText(osd), "Headphones");
        // the next press within the second brings no device: the name stays its second
        payload = volume(50, "");
        compare(valueText(osd), "Headphones");
        tryCompare(osd, "_deviceShown", false, Tokens.surfaces.osd.deviceNameMs + 2000);
        compare(valueText(osd), "50");
    }
    function test_a_later_device_change_shows_its_name() {
        payload = volume(30, "");
        const host = createTemporaryObject(hostComponent, testCase);
        tryVerify(() => host.item !== null);
        const osd = host.item;
        compare(valueText(osd), "30");
        payload = volume(30, "Speakers");
        compare(valueText(osd), "Speakers");
    }
    function test_another_kind_shows_its_own_value() {
        // every OSD is one layer updated in place (notch.js keyOf): brightness after a volume
        // device change shows its own value, not the audio device
        payload = volume(45, "Headphones");
        const host = createTemporaryObject(hostComponent, testCase);
        tryVerify(() => host.item !== null);
        const osd = host.item;
        compare(valueText(osd), "Headphones");
        payload = { kind: "brightness", glyph: "brightness_6", ink: "main", level: 60, max: 100, dots: -1, steps: 0,
                    value: "60", device: "" };
        compare(valueText(osd), "60");
        payload = volume(45, "");
        compare(valueText(osd), "45");
    }
}
