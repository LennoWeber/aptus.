// OKLab maths (08 §3).
import QtQuick
import QtTest
import "../../shell/core/js/colour.js" as Lib

TestCase {
    name: "colour"

    function test_hex_roundtrip() {
        compare(Lib.hexToRgb("#ff8000").join(","), "255,128,0")
        compare(Lib.hexToRgb("191613").join(","), "25,22,19")
        compare(Lib.rgbToHex([255, 128, 0]), "#ff8000")
        compare(Lib.rgbToHex([0, 5, 16]), "#000510")
        var list = ["#000000", "#ffffff", "#191613", "#efb07f", "#123456"]
        for (var i = 0; i < list.length; i++) {
            compare(Lib.rgbToHex(Lib.hexToRgb(list[i])), list[i])
            compare(Lib.oklabToHex(Lib.hexToOklab(list[i])), list[i])
        }
        var threw = false
        try { Lib.hexToRgb("#abc") } catch (e) { threw = true }
        verify(threw)
    }

    function test_rounding() {
        compare(Lib.rgbToHex([0.5, 1.49, 2.5]), "#010103")
        compare(Lib.rgbToHex([-4, 300, 254.5]), "#00ffff")
        compare(Lib.rgbToHex([127.4999, 127.5, 0]), "#7f8000")
    }

    function test_oklab_known_values() {
        var w = Lib.hexToOklab("#ffffff")
        fuzzyCompare(w[0], 1, 1e-3)
        fuzzyCompare(w[1], 0, 1e-3)
        fuzzyCompare(w[2], 0, 1e-3)
        var k = Lib.hexToOklab("#000000")
        fuzzyCompare(k[0], 0, 1e-3)
        var r = Lib.hexToOklab("#ff0000")
        fuzzyCompare(r[0], 0.62796, 1e-3)
        fuzzyCompare(r[1], 0.22486, 1e-3)
        fuzzyCompare(r[2], 0.12585, 1e-3)
        var lch = Lib.oklabToOklch(r)
        fuzzyCompare(lch[2], 29.23, 0.1)
        fuzzyCompare(lch[1], 0.2577, 1e-3)
    }

    function test_over_endpoints() {
        compare(Lib.over("#ff0000", "#191613", 0), "#191613")
        compare(Lib.over("#ff0000", "#191613", 1), "#ff0000")
        compare(Lib.mix("#000000", "#ffffff", 0), "#000000")
        compare(Lib.mix("#000000", "#ffffff", 1), "#ffffff")
        // mid grey in OKLab is darker than the sRGB midpoint
        var mid = Lib.hexToRgb(Lib.mix("#000000", "#ffffff", 0.5))
        verify(mid[0] < 128 && mid[0] > 90)
        compare(mid[0], mid[1])
        compare(mid[1], mid[2])
    }

    function test_toward() {
        compare(Lib.toward("#191613", "#efb07f", 0), "#191613")
        compare(Lib.toward("#191613", "#efb07f", 1), "#efb07f")
        var t = Lib.hexToOklab(Lib.toward("#191613", "#efe6d4", 0.35))
        var a = Lib.hexToOklab("#191613"), b = Lib.hexToOklab("#efe6d4")
        fuzzyCompare(t[0], a[0] + (b[0] - a[0]) * 0.35, 0.01)
        compare(Lib.toward("#123456", "#abcdef", 0.4), Lib.over("#abcdef", "#123456", 0.4))
    }

    function test_hue_distance() {
        compare(Lib.hueDistance(10, 350), 20)
        compare(Lib.hueDistance(350, 10), 20)
        compare(Lib.hueDistance(0, 180), 180)
        compare(Lib.hueDistance(90, 90), 0)
        compare(Lib.hueDistance(0, 270), 90)
        fuzzyCompare(Lib.hue("#ff0000"), 29.23, 0.1)
        verify(Lib.hue("#0000ff") > 260 && Lib.hue("#0000ff") < 270)
    }
}
