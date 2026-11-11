pragma Singleton
import QtQuick
// Test double of qs.services Apps: no icons, the class as the name.
QtObject {
    function iconFor(cls: string): string { return ""; }
    function nameFor(cls: string): string { return String(cls || ""); }
    function entryFor(cls: string): var { return null; }
}
