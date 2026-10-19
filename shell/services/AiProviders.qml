pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The AI CLIs of the launcher's AI mode: short one-shot questions, answer streams in line by line.
// Providers come from config/ai-providers.json plus the user's ~/.config/aptus/ai-providers.json (same format).
Singleton {
    id: root

    property var providers: []       // { id, name, command, quickArgs, enabled, builtIn, ... }
    property string defaultId        // from the shipped file
    property bool running

    signal chunk(string text)                  // one more line of the answer
    signal finished(bool ok, string error)

    readonly property string rootDir: Quickshell.env("APTUS_ROOT") || Quickshell.shellPath("..")
    readonly property string home: Quickshell.env("HOME")

    FileView {
        id: builtinFile
        path: root.rootDir + "/config/ai-providers.json"
        blockLoading: true
    }

    FileView {
        id: userFile
        path: root.home + "/.config/aptus/ai-providers.json"
        blockLoading: true
        printErrors: false   // only exists once the user adds a provider
    }

    Component.onCompleted: load()

    // Providers that can answer: enabled ones, in file order.
    function enabledProviders(): var {
        return providers.filter(p => p.enabled)
    }

    function find(providerId: string): var {
        return providers.find(p => p.id === providerId) || null
    }

    // Built-in providers plus the user's own.
    function load(): var {
        const out = []
        try {
            const shipped = JSON.parse(builtinFile.text())
            defaultId = shipped.default || ""
            for (const p of shipped.providers || []) out.push(Object.assign({ enabled: true }, p, { builtIn: true }))
        } catch (e) {
            console.warn("aptus: ai-providers.json not readable: " + e)
        }
        try {
            const own = JSON.parse(userFile.text())
            for (const p of own.providers || []) out.push(Object.assign({ enabled: true }, p, { builtIn: false, userAdded: true }))
        } catch (e) {
            // no user file
        }
        providers = out
        return out
    }

    // Command and arguments with the prompt filled in (never a shell string).
    function buildCommand(provider: var, prompt: string): var {
        if (!prompt || prompt.trim() === "") throw new Error("invariant: AiProviders.buildCommand: empty prompt")
        if (!provider.command || provider.command.indexOf(" ") >= 0) throw new Error("invariant: AiProviders.buildCommand: command must be one executable, never a shell string")
        if (!provider.quickArgs || provider.quickArgs.filter(a => a === "{prompt}").length !== 1) throw new Error("invariant: AiProviders.buildCommand: quickArgs must contain {prompt} exactly once")
        return [provider.command].concat(provider.quickArgs.map(a => a === "{prompt}" ? prompt : a))
    }

    // Ask a provider; the answer arrives through chunk(), the end through finished().
    function ask(providerId: string, prompt: string): void {
        const provider = find(providerId)
        if (!provider) throw new Error("invariant: AiProviders.ask: unknown provider")
        if (running) throw new Error("invariant: AiProviders.ask: a request is still running")
        process.command = buildCommand(provider, prompt)
        cancelled = false
        process.running = true
    }

    property bool cancelled

    function cancel(): void {
        if (!running) return
        cancelled = true
        process.running = false
    }

    Process {
        id: process
        workingDirectory: "/tmp"     // no project around: short questions only
        // qmllint disable incompatible-type
        environment: ({ PATH: root.home + "/.local/bin:" + Quickshell.env("PATH") })
        // qmllint enable incompatible-type
        stdout: SplitParser {
            onRead: data => root.chunk(data)
        }
        stderr: StdioCollector { id: errors }
        onRunningChanged: root.running = running
        // The exit status enum of Process is not known to qmllint.
        // qmllint disable signal-handler-parameters
        onExited: code => {
            if (root.cancelled) return
            root.finished(code === 0, code === 0 ? "" : (errors.text.trim().split("\n").pop() || "Exit code " + code))
        }
        // qmllint enable signal-handler-parameters
    }

    function add(provider: var): void {
        if (!provider || !provider.id) throw new Error("invariant: AiProviders.add: provider needs an id")
        if (provider.builtIn) throw new Error("invariant: AiProviders.add: built-in providers are not added by the user")
        if (!provider.quickArgs || provider.quickArgs.filter(a => a === "{prompt}").length !== 1) throw new Error("invariant: AiProviders.add: quickArgs must contain {prompt} exactly once")
        if ((providers || []).some(p => p.id === provider.id)) throw new Error("invariant: AiProviders.add: duplicate provider id")
        throw new Error("not implemented")
    }

    // Only user-added providers.
    function remove(providerId: string): void {
        if (!providerId) throw new Error("invariant: AiProviders.remove: empty provider id")
        if ((providers || []).some(p => p.id === providerId && p.builtIn)) throw new Error("invariant: AiProviders.remove: built-in providers cannot be removed")
        throw new Error("not implemented")
    }

    function setEnabled(providerId: string, on: bool): void {
        if (!providerId) throw new Error("invariant: AiProviders.setEnabled: empty provider id")
        if (!on && (providers || []).filter(p => p.enabled && p.id !== providerId).length === 0) throw new Error("invariant: AiProviders.setEnabled: the last enabled provider cannot be disabled")
        throw new Error("not implemented")
    }

    function saveUser(): void {
        throw new Error("not implemented")
    }
}
