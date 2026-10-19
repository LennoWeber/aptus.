pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components
import qs.services

// Entries of one category (or of the search), one calm list.
Item {
    id: page

    property var appState  // SettingsAppState
    property var appSettings
    // Re-evaluates when the query, category, advanced switch or the schema change.
    readonly property var shown: appState ? appState.visibleEntries() : []

    // Option list of a choice entry.
    function choicesOf(entry: var): var {
        if (entry.optionsFrom === "providers") return AiProviders.providers.filter(p => p.enabled).map(p => ({ id: p.id, label: p.name }))
        if (entry.optionsFrom) return (appSettings.get(entry.optionsFrom) || []).map(o => ({ id: o.id, label: o.name }))
        return (entry.options || []).map(o => ({ id: o, label: o }))
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.height + 90
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: flick.width - 8

            Label {
                visible: page.shown.length === 0
                width: parent.width
                topPadding: 40
                horizontalAlignment: Text.AlignHCenter
                text: page.appState && page.appState.query.trim() !== "" ? "No settings match." : "Nothing here yet."
                color: Tokens.inkFaint
            }
            Repeater {
                model: page.shown
                delegate: SettingRow {
                    id: item
                    required property var modelData
                    width: column.width
                    entry: item.modelData
                                    draftValue: page.appState.valueOf(item.modelData)
                    changed: item.modelData.id in page.appState.draftValues
                    isDefault: page.appState.isDefault(item.modelData)
                    editable: page.appState.editable(item.modelData)
                    choices: item.modelData.kind === "choice" ? page.choicesOf(item.modelData) : []
                    actionLabel: item.modelData.id === "about.export" ? "Export" : item.modelData.id === "about.import" ? "Import" : item.modelData.id === "about.reset" ? "Reset all" : "Open"
                    highlighted: page.appState.focusedEntryId === item.modelData.id
                    onValueEdited: value => page.appState.setDraft(item.modelData.id, value)
                    onResetRequested: page.appState.resetEntry(item.modelData.id)
                    onActionRequested: page.appState.runAction(item.modelData)
                    onHighlightedChanged: if (highlighted) page.reveal(item)
                    Component.onCompleted: if (highlighted) page.reveal(item)
                }
            }
        }
    }

    // Scroll to an entry and let the highlight fade after a moment.
    function reveal(item: var): void {
        Qt.callLater(() => { flick.contentY = Math.max(0, Math.min(item.y - 40, flick.contentHeight - flick.height)) })
        clearHighlight.restart()
    }
    Timer { id: clearHighlight; interval: 1800; onTriggered: page.appState.focusedEntryId = "" }
}
