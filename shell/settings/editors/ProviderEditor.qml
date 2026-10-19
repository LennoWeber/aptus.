import QtQuick

// Add, enable, test and remove AI providers.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): simple form: name, command, arguments with {prompt}; test button reports success or the reason.

    property var providers  // list of AiProvider
    signal providerAdded(var provider)
    signal providerRemoved(string providerId)
    signal providerToggled(string providerId, bool on)
    signal testRequested(string providerId)
}
