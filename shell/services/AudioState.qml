import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Audio state (PipeWire).
Scope {
    id: root

    // The default devices and everything that can be picked; PwObjectTracker keeps them bound.
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    property real volume: sink && sink.audio ? sink.audio.volume : 0     // 0..1, no overdrive (setVolume refuses values above 1)
    property bool muted: sink && sink.audio ? sink.audio.muted : false
    property string outputName: sink ? describe(sink) : ""
    property var outputs: listNodes(true)         // list of { id, name, active }
    property real inputVolume: source && source.audio ? source.audio.volume : 0
    property bool inputMuted: source && source.audio ? source.audio.muted : false
    property string inputName: source ? describe(source) : ""
    property var inputs: listNodes(false)         // list of { id, name, active }

    // Real devices (sinks and sources, no streams of single programs). They must be tracked to be usable.
    readonly property var devices: Array.from(Pipewire.nodes.values).filter(n => n.type === PwNodeType.AudioSink || n.type === PwNodeType.AudioSource)

    // The type of a node is only known once it is tracked, so every node is tracked.
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    function describe(node: var): string {
        return node.description || node.nickname || node.name
    }

    function listNodes(sinks: bool): var {
        const current = sinks ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource
        const wanted = sinks ? PwNodeType.AudioSink : PwNodeType.AudioSource
        return devices
            .filter(n => n.type === wanted)
            .map(n => ({ id: n.name, name: describe(n), active: current !== null && n.name === current.name }))
    }

    function nodeByName(name: string, sinks: bool): var {
        const wanted = sinks ? PwNodeType.AudioSink : PwNodeType.AudioSource
        return devices.find(n => n.type === wanted && n.name === name)
    }

    function setVolume(level: real): void {
        if (!(level >= 0 && level <= 1)) throw new Error("invariant: AudioState.setVolume: volume outside 0..1 (no overdrive)")
        if (sink && sink.audio) sink.audio.volume = level
    }

    // Function keys.
    function changeVolume(delta: real): void {
        if (!Number.isFinite(delta)) throw new Error("invariant: AudioState.changeVolume: delta must be a number")
        // TODO(phase 7, OSD section): show the on-screen indicator immediately on function-key presses.
        setVolume(Math.max(0, Math.min(1, volume + delta)))
    }

    function setMuted(on: bool): void {
        if (sink && sink.audio) sink.audio.muted = on
    }

    function toggleMute(): void {
        setMuted(!muted)
    }

    function setOutput(outputId: string): void {
        if (!outputId) throw new Error("invariant: AudioState.setOutput: empty output id")
        const node = nodeByName(outputId, true)
        if (node) Pipewire.preferredDefaultAudioSink = node
    }

    function setInputVolume(level: real): void {
        if (!(level >= 0 && level <= 1)) throw new Error("invariant: AudioState.setInputVolume: volume outside 0..1")
        if (source && source.audio) source.audio.volume = level
    }

    function toggleInputMute(): void {
        if (source && source.audio) source.audio.muted = !inputMuted
    }

    function setInput(inputId: string): void {
        if (!inputId) throw new Error("invariant: AudioState.setInput: empty input id")
        const node = nodeByName(inputId, false)
        if (node) Pipewire.preferredDefaultAudioSource = node
    }
}
