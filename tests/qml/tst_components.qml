// The component library (03 §9) against test doubles of qs.core and Quickshell
// (tests/qml/mock, built by tests/qml/mkmock.py): the real Quickshell plugin does not load in
// qmltestrunner. Run through tests/run.
import QtQuick
import QtTest
import qs.core
import qs.components

Item {
    id: top
    width: 800
    height: 600

    Component { id: menuComp; Menu {} }
    Component { id: hostComp; MenuHost {} }
    Component { id: stateComp; MonitorState {} }
    Component { id: modeComp; NotchMode {} }

    Label { id: label; text: "Hello"; type: "title" }
    Glyph { id: glyph; name: "wifi"; on: true }
    Glyph { id: swapGlyph; x: 40; name: "wifi" }
    Field { id: field; y: 100; width: 300 }
    Slider { id: slider; y: 200; width: 300; levelGlyphs: ["a", "b", "c", "d"]; value: 0.5 }
    Segmented { id: seg; y: 250; options: [{ value: 1, label: "One" }, { value: 2, label: "Two" }, { value: 3, label: "Three" }]; value: 2 }
    RollingDigits { id: digits; y: 300; text: "9:59"; role: "clock" }
    Switch { id: sw; y: 350 }
    Ellipsis { id: ell; y: 380 }
    Button { id: button; y: 400; text: "Retry"; tooltip: "Try again" }
    Tile { id: tile; y: 450; glyph: "wifi"; label: "Wi-Fi"; stateText: "Home"; hasPage: true }
    Badge { id: badge; x: 400; count: 5 }
    Level { id: level; x: 400; y: 20; width: 200; value: 1.2; max: 1.5 }
    Ring { id: ring; x: 400; y: 40; width: 20; height: 20; progress: 0.5 }
    AppIcon { id: appIcon; x: 400; y: 80; icon: "missing-icon"; name: "zen" }
    Thumb { id: thumb; x: 400; y: 120; width: 50; height: 30 }
    EmptyState { id: empty; x: 400; y: 160; glyph: "inbox"; text: "Nothing here"; actionText: "Refresh" }
    ErrorLine { id: err; x: 400; y: 260; text: "Could not reach it." }
    PagerDots { id: dots; x: 400; y: 300; count: 3; current: 1 }
    Swatch { id: swatch; x: 400; y: 320; colour: Tokens.accent; name: "Jade" }
    Checkbox { id: cb; x: 400; y: 350 }
    Keycap { id: keycap; x: 400; y: 380; text: "Super" }
    Scrim { id: scrim; x: 600; width: 10; height: 10 }
    List {
        id: list
        x: 500; y: 400; width: 200; height: 120
        model: 10
        delegate: ListRow {
            required property int index
            width: ListView.view.width
            title: "Row " + index
            glyph: "apps"
            keycaps: index < 2 ? ["Ctrl", "1"] : []
            current: ListView.isCurrentItem
        }
    }

    SignalSpy { id: trigSpy; signalName: "triggered" }
    SignalSpy { id: dismissSpy; signalName: "dismissed" }
    SignalSpy { id: editSpy; target: field; signalName: "edited" }
    SignalSpy { id: actSpy; target: list; signalName: "activatedAt" }
    SignalSpy { id: segSpy; target: seg; signalName: "selected" }
    SignalSpy { id: swSpy; target: sw; signalName: "toggled" }
    SignalSpy { id: slSpy; target: slider; signalName: "moved" }
    SignalSpy { id: btnSpy; target: button; signalName: "clicked" }

    // outside-press target and two tooltip owners (MenuHost, Tooltip regrace)
    Rectangle {
        id: under
        x: 700; y: 200; width: 90; height: 90
        property int presses: 0
        MouseArea { anchors.fill: parent; onPressed: under.presses++ }
    }
    Item { id: focusTarget; focus: true }
    IconButton { id: b1; x: 10; y: 560; glyph: "wifi"; tooltip: "One" }
    IconButton { id: b2; x: 60; y: 560; glyph: "wifi"; tooltip: "Two" }
    IconButton { id: offButton; x: 110; y: 560; glyph: "bluetooth"; tooltip: "Bluetooth"; disabledReason: "Bluetooth is off" }
    Button { id: offPlain; x: 160; y: 560; text: "Connect"; disabledReason: "No network" }
    SignalSpy { id: offSpy; target: offButton; signalName: "clicked" }
    SignalSpy { id: offPlainSpy; target: offPlain; signalName: "clicked" }

    // The tooltip of a given text (tooltips reparent to the window's content item).
    function tipOf(text) {
        const kids = top.Window.contentItem.children;
        for (let i = 0; i < kids.length; i++) if (kids[i].hasOwnProperty("_want") && kids[i].text === text) return kids[i];
        return null;
    }

    TestCase {
        name: "components"
        when: windowShown

        function test_label_glyph() {
            verify(Tokens.raw.components !== undefined, "tokens loaded");
            compare(Tokens.button.height, 32);
            verify(Tokens.inkMain.valid);
            compare(label.font.pixelSize, 15);
            compare(label.lineHeight, 20);
            compare(glyph.width, 18);
            tryCompare(ComponentShared, "glyphFamily", "Material Symbols Rounded");
            compare(glyph.font.variableAxes["FILL"], 1);
        }
        function test_menu_keyboard() {
            const m = menuComp.createObject(top, { model: [
                { id: "a", label: "Alpha", glyph: "edit" },
                { separator: true },
                { id: "b", label: "Beta", enabled: false },
                { id: "c", label: "Close all", risk: true, confirm: "Close 4 windows?" },
                { id: "d", label: "More", submenu: [{ id: "d1", label: "One" }, { id: "d2", label: "Two" }] }
            ], anchorX: 100, anchorY: 50 });
            verify(m);
            trigSpy.target = m; trigSpy.clear();
            dismissSpy.target = m; dismissSpy.clear();
            compare(m.currentIndex, -1);
            m.moveCurrent(1); compare(m.currentIndex, 0);
            m.moveCurrent(1); compare(m.currentIndex, 3, "skips separator and disabled");
            m.moveCurrent(1); compare(m.currentIndex, 4);
            m.moveCurrent(1); compare(m.currentIndex, 0, "wraps");
            m.moveCurrent(-1); compare(m.currentIndex, 4);
            m.moveCurrent(-1); compare(m.currentIndex, 3);
            // confirm row: first trigger asks, second runs
            m.triggerCurrent();
            compare(trigSpy.count, 0);
            compare(m._confirmIndex, 3);
            m.triggerCurrent();
            compare(trigSpy.count, 1);
            compare(trigSpy.signalArguments[0][0].id, "c");
            // confirm cancelled by moving
            m.triggerCurrent(); compare(m._confirmIndex, 3);
            m.moveCurrent(1); compare(m._confirmIndex, -1);
            // submenu via keyboard
            m.forceActiveFocus();
            keyClick(Qt.Key_Right);
            compare(m._subIndex, 4);
            verify(m.width > 0 && m.height > 0);
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            compare(trigSpy.count, 2);
            compare(trigSpy.signalArguments[1][0].id, "d2");
            // ← closes the submenu, Esc dismisses the root
            keyClick(Qt.Key_Left);
            compare(m._subIndex, -1);
            keyClick(Qt.Key_Escape);
            compare(dismissSpy.count, 1);
            // geometry: grows from the anchor, flips left when there is no room
            compare(m.x, 100); compare(m.y, 50);
            m.anchorX = 790;
            verify(m.x + m.width <= 800);
            m.destroy();
        }
        function test_menu_host() {
            const st = stateComp.createObject(top, { name: "A" });
            SurfaceManager.monitors = { "A": st };
            const host = hostComp.createObject(top, { monitor: st, width: 800, height: 600 });
            let got = null;
            SurfaceManager.openMenu("A", { anchorX: 10, anchorY: 10, owner: "test", model: [{ id: "x", label: "X" }],
                                          onTriggered: row => { got = row.id; } });
            wait(50);
            const c0 = SurfaceManager.closeCalls;
            // the menu has focus: Down + Enter triggers
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            compare(got, "x");
            compare(SurfaceManager.closeCalls, c0 + 1);
            compare(st.menu, null);
            tryCompare(host, "_shown", null, 1000);
            host.destroy(); st.destroy();
        }
        function test_field() {
            field.text = "abc";
            editSpy.clear();
            field.clear();
            compare(field.text, "");
            compare(editSpy.count, 1);
            compare(field.input.text, "");
            field.forceFocus();
            keyClick(Qt.Key_X);
            compare(field.text, "x");
            compare(editSpy.count, 2);
            keyClick(Qt.Key_Backspace, Qt.ControlModifier);
            compare(field.text, "");
        }
        function test_slider() {
            compare(slider._glyph, "c");
            slider.value = 0; compare(slider._glyph, "a");
            slider.value = 0.1; compare(slider._glyph, "b");
            slider.value = 1; compare(slider._glyph, "d");
            slider.value = 0.5;
            slSpy.clear();
            slider.forceActiveFocus();
            keyClick(Qt.Key_Right);
            compare(slSpy.count, 1);
            fuzzyCompare(slSpy.signalArguments[0][0], 0.55, 1e-9);
            mouseDrag(slider, 100, slider.height / 2, 80, 0);
            verify(slSpy.count > 2);
            compare(slider.dragging, false);
        }
        function test_segmented() {
            compare(seg._index, 1);
            verify(seg.implicitWidth > 0);
            seg.forceActiveFocus();
            segSpy.clear();
            keyClick(Qt.Key_Right);
            compare(segSpy.count, 1);
            compare(segSpy.signalArguments[0][0], 3);
        }
        function test_digits() {
            compare(digits.text, "9:59");
            digits.text = "10:00";
            wait(10);
            verify(digits.implicitWidth > 0);
            tryCompare(digits, "implicitWidth", digits.implicitWidth, 1000);
        }
        function test_switch_button() {
            swSpy.clear();
            mouseMove(sw, 5, 5); mouseClick(sw);
            compare(swSpy.count, 1);
            compare(swSpy.signalArguments[0][0], true);
            compare(sw.checked, false, "controlled");
            btnSpy.clear();
            mouseMove(button, 5, 5); mouseClick(button);
            compare(btnSpy.count, 1);
            compare(button.height, 32);
            verify(button.width > button.height);
        }
        function test_ellipsis() {
            ell.running = true;
            compare(ell.opacity, 0);
            tryVerify(() => ell.opacity === 1, 1500);
            ell.running = false;
            tryVerify(() => !ell.visible, 1000);
        }
        function test_list() {
            list.forceActiveFocus();
            list.currentIndex = 0;
            keyClick(Qt.Key_Down);
            compare(list.currentIndex, 1);
            keyClick(Qt.Key_N, Qt.ControlModifier);
            compare(list.currentIndex, 2);
            keyClick(Qt.Key_End);
            compare(list.currentIndex, 9);
            keyClick(Qt.Key_Home);
            compare(list.currentIndex, 0);
            actSpy.clear();
            keyClick(Qt.Key_Return);
            compare(actSpy.count, 1);
            verify(list.highlightItem !== null);
            const row = list.itemAtIndex(0);
            compare(row._viewHighlights, true);
        }
        function test_misc() {
            verify(badge.width > badge.height - 1);
            verify(level._fill > 0);
            compare(appIcon._ready, false);
            verify(empty.implicitWidth > 0);
            verify(err.implicitWidth > 0);
            compare(dots.implicitWidth, 3 * 6 + 2 * 6);
            compare(keycap.height, 18);
            compare(tile.width, 88);
            tile.stateText = "Off";
            compare(tile._oldState, "Home");
        }
        function test_tooltip() {
            // start cold: no tooltip shown or hidden within the regrace (03 §9)
            mouseMove(top, 780, 20);
            tryVerify(() => !ComponentShared.tooltipWarm(), 2000);
            mouseMove(button, 10, 10);
            wait(50);
            const t = top.tipOf("Try again");
            verify(t, "tooltips reparented to the content item");
            compare(t._want, true);
            compare(t._shown, false);
            tryCompare(t, "_shown", true, 1500);
            mouseMove(top, 780, 20);
            tryCompare(t, "_shown", false, 500);
        }
        function test_outside_and_focus() {
            const st = stateComp.createObject(top, { name: "A" });
            SurfaceManager.monitors = { "A": st };
            const host = hostComp.createObject(top, { monitor: st, width: 800, height: 600 });
            focusTarget.forceActiveFocus();
            verify(focusTarget.activeFocus);
            SurfaceManager.openMenu("A", { anchorX: 10, anchorY: 10, owner: "t", model: [{ label: "X" }, { label: "Y" }] });
            wait(30);
            verify(!focusTarget.activeFocus, "menu took the focus");
            // a press inside the menu padding does not close it
            mousePress(host, 14, 12); mouseRelease(host, 14, 12);
            wait(20);
            verify(st.menu !== null, "inside press keeps the menu");
            // outside press: delivered underneath, then the menu closes
            mousePress(top, 740, 240); mouseRelease(top, 740, 240);
            compare(under.presses, 1);
            tryCompare(st, "menu", null, 500);
            tryVerify(() => focusTarget.activeFocus, 500, "focus restored");
            // Esc closes
            SurfaceManager.openMenu("A", { anchorX: 10, anchorY: 10, owner: "t", model: [{ label: "X" }] });
            wait(30);
            keyClick(Qt.Key_Escape);
            compare(st.menu, null);
            tryCompare(host, "_shown", null, 1000);
            host.destroy(); st.destroy();
        }
        function test_tooltip_regrace() {
            mouseMove(top, 780, 20);
            tryVerify(() => !ComponentShared.tooltipWarm(), 2000);
            mouseMove(b1, 5, 5);
            const t1 = top.tipOf("One"), t2 = top.tipOf("Two");
            verify(t1 && t2);
            tryCompare(t1, "_shown", true, 1500);
            mouseMove(b2, 5, 5);
            wait(30);
            compare(t1._shown, false);
            compare(t2._shown, true, "no delay within the regrace");
            mouseMove(top, 780, 20);
            wait(1200);
            mouseMove(b1, 5, 5);
            wait(100);
            compare(t1._shown, false, "delay again after the regrace");
            mouseMove(top, 780, 20);
        }
        function test_glyph_swap() {
            // 04 §3 rule 6: the old glyph fades out while the new one scales 0.8 → 1
            compare(swapGlyph._current, "wifi");
            swapGlyph.name = "bluetooth";
            compare(swapGlyph._previous, "wifi");
            compare(swapGlyph._current, "bluetooth");
            verify(swapGlyph._swap < 1, "the swap runs");
            tryCompare(swapGlyph, "_swap", 1, 1000);
        }
        function test_disabled_reason() {
            // 03 §8: no click, hover stays, the tooltip says why
            offSpy.clear(); offPlainSpy.clear();
            mouseMove(offButton, 5, 5); mouseClick(offButton);
            mouseMove(offPlain, 5, 5); mouseClick(offPlain);
            compare(offSpy.count, 0);
            compare(offPlainSpy.count, 0);
            verify(top.tipOf("Bluetooth is off"), "the IconButton's tooltip is the reason");
            verify(top.tipOf("No network"), "the Button's tooltip is the reason");
            mouseMove(offButton, 5, 5);
            tryCompare(top.tipOf("Bluetooth is off"), "_shown", true, 1500);
            mouseMove(top, 780, 20);
        }
        function test_choreography() {
            // 04 §3 rule 1: content after the container, out first on exit
            const m = modeComp.createObject(top, { width: 100, height: 40 });
            compare(m.opacity, 0);
            tryCompare(m, "opacity", 1, 1000);
            m.active = false;
            tryCompare(m, "opacity", 0, 1000);
            m.destroy();
        }
    }
}
