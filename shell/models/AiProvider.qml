import QtQuick

// One AI CLI. Used two ways:
//  - launcher AI mode: short one-shot questions (quickArgs)
//  - app launcher: entry that starts the CLI interactively in the terminal
// Providers are loaded from config/ai-providers.json, so adding one needs no code change.
QtObject {
    property string id
    property string name
    property string command          // executable, e.g. "claude"
    property var quickArgs           // argument template for short questions; "{prompt}" is replaced
    property bool streaming          // does the CLI stream its output?
    property bool launchInTerminal   // show an entry in the app launcher
    property string iconName
    property bool supportsUsage      // can usage be queried for the tile?
    property string usageCommand     // optional command that prints usage
    property bool enabled
    property bool builtIn            // shipped with aptus, can be disabled but not removed
    property bool userAdded          // added in the settings app, stored in the user config
    property bool installed          // detected on PATH at startup

    // Command and arguments with the prompt filled in.
    function buildCommand(prompt: string): var {
        if (!prompt || prompt.trim() === "") throw new Error("invariant: AiProvider.buildCommand: empty prompt")
        if (!command || command.indexOf(" ") >= 0) throw new Error("invariant: AiProvider.buildCommand: command must be one executable, never a shell string")
        if (!quickArgs || quickArgs.filter(a => a === "{prompt}").length !== 1) throw new Error("invariant: AiProvider.buildCommand: quickArgs must contain {prompt} exactly once")
        // TODO(phase 7): restrict tools for short questions (e.g. vibe --enabled-tools); these CLIs are coding agents.
        throw new Error("not implemented")
    }

    function detectInstalled(): bool {
        if (!command) throw new Error("invariant: AiProvider.detectInstalled: empty command")
        throw new Error("not implemented")
    }

    // Check the command (used by the settings app).
    function test(): void {
        if (!command) throw new Error("invariant: AiProvider.test: empty command")
        throw new Error("not implemented")
    }
}
