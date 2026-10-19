import QtQuick

// Edit keyboard shortcuts.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): press the new combination to record it; conflicts shown immediately.

    property var bindings  // list of HotkeyBinding
    signal bindingChanged(string bindingId, var binding)
}
