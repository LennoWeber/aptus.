pragma Singleton
// Idle: dim, lock, screen off, keep awake.
// Owner: S6. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool keepAwake: false
    property bool dimmed: false
    // Keep awake (Deck tile, Spotlight Caffeine).
    function setKeepAwake(on: bool): void { throw new Error("Idle.setKeepAwake: not implemented"); }
}
