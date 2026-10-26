pragma ComponentBehavior: Bound
import QtQuick
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

    // True if shown[index] opens a new section (a different section than the entry before it).
    function startsSection(index: int): bool {
        const s = page.shown
        if (index < 0 || index >= s.length) return false
        return index === 0 || s[index].section !== s[index - 1].section
    }

    // Sub-headings only on a category page that has more than one section.
    readonly property bool sectioned: !!appState && appState.query.trim() === "" && new Set(shown.map(e => e.section)).size > 1

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
                delegate: Column {
                    id: block
                    required property var modelData
                    required property int index
                    width: column.width

                    SectionHeader {
                        visible: page.sectioned && page.startsSection(block.index)
                        width: parent.width
                        height: visible ? implicitHeight : 0
                        title: block.modelData.section || ""
                        first: block.index === 0
                    }
                    SettingRow {
                        id: item
                        width: block.width
                        entry: block.modelData
                        draftValue: page.appState.valueOf(block.modelData)
                        changed: block.modelData.id in page.appState.draftValues
                        isDefault: page.appState.isDefault(block.modelData)
                        editable: page.appState.editable(block.modelData)
                        origin: page.appState.query.trim() !== "" ? page.appState.originOf(block.modelData) : ""
                        choices: block.modelData.kind === "choice" ? page.choicesOf(block.modelData) : []
                        actionLabel: block.modelData.id === "about.export" ? "Export" : block.modelData.id === "about.import" ? "Import" : block.modelData.id === "about.reset" ? "Reset all" : "Open"
                        highlighted: page.appState.focusedEntryId === block.modelData.id
                        onValueEdited: value => page.appState.setDraft(block.modelData.id, value)
                        onResetRequested: page.appState.resetEntry(block.modelData.id)
                        onActionRequested: page.appState.runAction(block.modelData)
                        onHighlightedChanged: if (highlighted) page.reveal(item)
                        Component.onCompleted: if (highlighted) page.reveal(item)
                    }
                }
            }
        }
    }

    // Scroll to an entry and let the highlight fade after a moment.
    function reveal(item: var): void {
        Qt.callLater(() => { flick.contentY = Math.max(0, Math.min(item.mapToItem(column, 0, 0).y - 40, flick.contentHeight - flick.height)) })
        clearHighlight.restart()
    }
    Timer { id: clearHighlight; interval: 1800; onTriggered: page.appState.focusedEntryId = "" }
}
