import QtQuick
import Quickshell
import qs.models
import qs.theme
import qs.components

// Settings app: its own window with the categories on the left, search on top, the page on the right and the
// change bar at the bottom. Advanced entries stay hidden until "Show advanced" is on.
FloatingWindow {
    id: win

    property var appState  // SettingsAppState
    property var appSettings

    title: "aptus settings"
    visible: appState ? appState.open : false
    implicitWidth: 980
    implicitHeight: 680
    minimumSize: Qt.size(720, 480)
    color: Tokens.bg

    // Closing the window by its own button.
    onVisibleChanged: if (!visible && appState && appState.open) appState.closeWindow()

    function showWindow(): void { appState.openWindow("") }
    function hideWindow(): void { appState.closeWindow() }

    Shortcut {
        sequence: "Escape"
        enabled: win.visible && win.appState.phase !== Enums.ApplyPhase.AwaitingConfirm
        onActivated: win.appState.query !== "" ? win.appState.setQuery("") : win.appState.closeWindow()
    }
    Shortcut {
        sequence: "Ctrl+F"
        enabled: win.visible
        onActivated: search.focusInput()
    }

    Rectangle { anchors.fill: parent; color: Tokens.bg }

    Label {
        x: 26
        y: 22
        text: "Settings"
        role: Enums.TextRole.Title
    }

    Sidebar {
        id: sidebar
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 230
        categories: win.appState ? win.appState.categories : []
        activeCategoryId: win.appState ? win.appState.activeCategoryId : ""
        onCategorySelected: id => win.appState.setCategory(id)
    }
    Rectangle { anchors { left: sidebar.right; top: parent.top; bottom: parent.bottom } width: 1; color: Tokens.line }

    Item {
        anchors { left: sidebar.right; leftMargin: 1; right: parent.right; top: parent.top; bottom: parent.bottom }

        SearchField {
            id: search
            anchors { left: parent.left; leftMargin: 28; top: parent.top; topMargin: 16 }
            width: 340
            query: win.appState ? win.appState.query : ""
            onEdited: text => win.appState.setQuery(text)
        }
        ToggleSwitch {
            anchors { right: parent.right; rightMargin: 28; verticalCenter: search.verticalCenter }
            implicitWidth: 170
            width: 170
            label: "Show advanced"
            checked: win.appState ? win.appState.showAdvanced : false
            onToggled: value => win.appState.showAdvanced = value
        }

        Label {
            id: heading
            anchors { left: parent.left; leftMargin: 28; top: search.bottom; topMargin: 20 }
            text: {
                if (!win.appState) return ""
                if (win.appState.query.trim() !== "") return "Search"
                const c = win.appState.categories.find(c => c.id === win.appState.activeCategoryId)
                return c ? c.title : ""
            }
            role: Enums.TextRole.Title
        }
        Label {
            anchors { left: heading.right; leftMargin: 14; baseline: heading.baseline }
            visible: !!win.appState && win.appState.notice !== ""
            text: win.appState ? win.appState.notice : ""
            role: Enums.TextRole.Bar
            color: Tokens.inkSoft
        }

        CategoryPage {
            anchors { left: parent.left; leftMargin: 28; right: parent.right; rightMargin: 28; top: heading.bottom; topMargin: 12; bottom: parent.bottom }
            appState: win.appState
            appSettings: win.appSettings
        }

        ChangeBar {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            hasUnsavedChanges: win.appState ? win.appState.hasUnsavedChanges && win.appState.phase !== Enums.ApplyPhase.AwaitingConfirm : false
            changedCount: win.appState ? win.appState.changedEntryIds.length : 0
            onSaveRequested: win.appState.save()
            onDiscardRequested: win.appState.discardDraft()
        }
    }
}
