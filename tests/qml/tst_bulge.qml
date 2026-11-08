// Frame path (03 §6.2).
import QtQuick
import QtTest
import "../../shell/core/js/bulge.js" as Lib

TestCase {
    name: "bulge"

    function count(s, ch) { return s.split(ch).length - 1 }

    function test_no_bulges_is_band() {
        var p = Lib.framePath(1000, 600, 6, 32, 18, [])
        compare(p.indexOf("M -2 -2 L 1002 -2 L 1002 602 L -2 602 Z"), 0)
        // inner outline: 4 corner arcs, top edge at y=32, sides at x=6 and x=994, bottom at 594
        compare(count(p, "A "), 4)
        verify(p.indexOf("M 6 50 A 18 18 0 0 1 24 32") > 0)
        verify(p.indexOf("L 976 32 A 18 18 0 0 1 994 50") > 0)
        verify(p.indexOf("L 994 576 A 18 18 0 0 1 976 594") > 0)
        verify(p.indexOf("L 24 594 A 18 18 0 0 1 6 576 Z") > 0)
        compare(Lib.framePath(1000, 600, 6, 32, 18, null), p)
        compare(Lib.bodiesPath(1000, 6, 32, []), "")
    }

    function test_one_bulge_dent() {
        var p = Lib.framePath(1000, 600, 6, 32, 18,
            [{ dock: "top", x: 300, width: 400, height: 100, cove: 14, radius: 18 }])
        // cove into the bulge at x=300, bottom of the bulge at y=132
        verify(p.indexOf("L 286 32 A 14 14 0 0 1 300 46") > 0)
        verify(p.indexOf("L 300 114 A 18 18 0 0 0 318 132") > 0)
        verify(p.indexOf("L 682 132 A 18 18 0 0 0 700 114") > 0)
        verify(p.indexOf("L 700 46 A 14 14 0 0 1 714 32") > 0)
        compare(count(p, "A "), 4 + 4)
    }

    function test_full_width_bulge() {
        var p = Lib.framePath(1000, 600, 6, 32, 18,
            [{ dock: "topFull", x: 0, width: 10, height: 80, cove: 5, radius: 5 }])
        // the content area starts below bar + full bulge: top edge at y=112, no extra arcs
        verify(p.indexOf("M 6 130 A 18 18 0 0 1 24 112") > 0)
        compare(count(p, "A "), 4)
        var b = Lib.bodiesPath(1000, 6, 32, [{ dock: "topFull", height: 80 }])
        compare(b, "M 6 32 L 994 32 L 994 112 L 6 112 Z")
    }

    function test_corner_docks() {
        var p = Lib.framePath(1000, 600, 6, 32, 18, [
            { dock: "topLeft", width: 200, height: 60, cove: 10, radius: 12 },
            { dock: "topRight", width: 150, height: 60, cove: 10, radius: 12 }])
        // topLeft starts on the left edge below the bar+height, topRight ends on the right edge
        verify(p.indexOf("M 6 102 A 10 10 0 0 1 16 92") > 0)
        verify(p.indexOf("L 194 92 A 12 12 0 0 0 206 80") > 0)
        verify(p.indexOf("L 984 92 A 10 10 0 0 1 994 102") > 0)
        // no regular top-left/top-right content corner arc of radius 18 at the top
        verify(p.indexOf("A 18 18 0 0 1 24 32") < 0)
        verify(p.indexOf("A 18 18 0 0 1 994 50") < 0)
    }

    function test_overlap_merge() {
        var one = Lib.framePath(1000, 600, 6, 32, 18,
            [{ dock: "top", x: 300, width: 300, height: 80, cove: 14, radius: 18 }])
        var two = Lib.framePath(1000, 600, 6, 32, 18, [
            { dock: "top", x: 300, width: 200, height: 80, cove: 14, radius: 18 },
            { dock: "top", x: 400, width: 200, height: 60, cove: 14, radius: 18 }])
        compare(two, one)
        // nearby bulges whose coves touch merge too
        var near = Lib.framePath(1000, 600, 6, 32, 18, [
            { dock: "top", x: 500, width: 100, height: 80, cove: 14, radius: 18 },
            { dock: "top", x: 300, width: 190, height: 80, cove: 14, radius: 18 }])
        compare(near, Lib.framePath(1000, 600, 6, 32, 18,
            [{ dock: "top", x: 300, width: 300, height: 80, cove: 14, radius: 18 }]))
        // far apart stay separate
        var apart = Lib.framePath(1000, 600, 6, 32, 18, [
            { dock: "top", x: 100, width: 100, height: 80, cove: 14, radius: 18 },
            { dock: "top", x: 600, width: 100, height: 80, cove: 14, radius: 18 }])
        compare(count(apart, "A "), 4 + 8)
    }

    function test_tiny_bulge_dropped() {
        var band = Lib.framePath(1000, 600, 6, 32, 18, [])
        compare(Lib.framePath(1000, 600, 6, 32, 18,
            [{ dock: "top", x: 300, width: 400, height: 0.2, cove: 14, radius: 18 }]), band)
        compare(Lib.framePath(1000, 600, 6, 32, 18,
            [{ dock: "top", x: 300, width: 0.1, height: 80, cove: 14, radius: 18 }]), band)
        compare(Lib.framePath(1000, 600, 6, 32, 18,
            [{ dock: "top", x: 300, width: 400, height: 80, shown: false }]), band)
        var n = Lib.normalise([{ dock: "top", x: -50, width: 2000, height: 80, cove: 14, radius: 18 }], 1000, 6)
        compare(n.bulges.length, 1)
        compare(n.bulges[0].x, 6)
        compare(n.bulges[0].width, 988)
    }

    function test_bodies_path() {
        var b = Lib.bodiesPath(1000, 6, 32, [{ dock: "top", x: 300, width: 400, height: 100, cove: 14, radius: 18 }])
        compare(b, "M 300 32 L 700 32 L 700 114 A 18 18 0 0 1 682 132 L 318 132 A 18 18 0 0 1 300 114 Z")
        compare(Lib.bodiesPath(1000, 6, 32, []), "")
    }
}
