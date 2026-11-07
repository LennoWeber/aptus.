pragma Singleton
// Idle: dim, lock, screen off, keep awake.
// Owner: S6. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): until S6 fills this service, each action method logs "not available yet"
    //   (category service.<name>) instead of throwing (phase-1 decision 6).

    property bool keepAwake: false
    property bool dimmed: false
    // Keep awake (Deck tile, Spotlight Caffeine).
    function setKeepAwake(on: bool): void { throw new Error("Idle.setKeepAwake: not implemented"); }
}
