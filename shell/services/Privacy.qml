pragma Singleton
pragma ComponentBehavior: Bound
// Privacy: mic, camera, screencast in use.
// Owner: S3.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.core
import "js/status.js" as S

Singleton {
    id: root

    // apps using the microphone
    property var mic: []
    // apps using a camera
    property var camera: []
    readonly property bool screencast: Hypr.screencast
    // The service works (S3); under APTUS_TEST only the screencast part (no PipeWire).
    readonly property bool available: true

    // Rebuild mic and camera from the PipeWire nodes (status.js privacy); never under Paths.test.
    function _rebuild(): void {
        const b = backend.item;
        if (!b) return;
        const linked = {};
        for (const g of Pipewire.linkGroups.values)
            if (g.state === PwLinkState.Active && g.source) linked[g.source.id] = true;
        const nodes = Pipewire.nodes.values.map(n => {
            const p = n.properties || {};
            return { isStream: n.isStream, mediaClass: String(p["media.class"] || ""),
                     app: String(p["application.name"] || n.description || n.name || ""), linked: !!linked[n.id] };
        });
        const r = S.privacy(nodes);
        if (JSON.stringify(r.mic) !== JSON.stringify(mic)) mic = r.mic;
        if (JSON.stringify(r.camera) !== JSON.stringify(camera)) camera = r.camera;
    }

    // Coalesces the graph's bursts; within surfaces.bar.privacyAppearMaxMs.
    Timer {
        id: kick
        interval: Tokens.surfaces.bar.privacyAppearMaxMs / 2
        onTriggered: root._rebuild()
    }
    // The PipeWire side, never loaded under the test (no connection to the real graph).
    LazyLoader {
        id: backend
        active: !Paths.test
        component: Item {
            readonly property var nodes: Pipewire.nodes.values
            readonly property var groups: Pipewire.linkGroups.values
            onNodesChanged: kick.restart()
            onGroupsChanged: kick.restart()
            Instantiator {
                model: Pipewire.linkGroups
                delegate: Connections {
                    required property var modelData
                    target: modelData
                    function onStateChanged(): void { kick.restart(); }
                }
            }
        }
    }
}
