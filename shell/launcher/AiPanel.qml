import QtQuick

// Docked side panel for short AI questions.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): narrow column at the screen edge, provider name in the header with Alt+arrow hint, messages scroll, input at the bottom.
    // TODO(phase 7): no tools, no history after closing.

    property var launcherState  // LauncherState
    property string providerName
    property var providers  // list of AiProvider
    property int panelWidthPx
    signal sendRequested(string text)

    function scrollToEnd(): void {
        throw new Error("not implemented")
    }
}
