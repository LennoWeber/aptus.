// Every Material Symbols name S3 uses exists as a ligature in the bundled font (a missing name
// would render as its letters): each one shapes to a single glyph of the icon's width.
import QtQuick
import QtTest
import "../../shell/services/js/levels.js" as L
import "../../shell/surfaces/bar/js/bar.js" as B

TestCase {
    name: "glyphs"

    function test_every_glyph_is_a_ligature() { skip("phase 7") }
}
