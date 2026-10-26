pragma ComponentBehavior: Bound
import QtQuick
import qs.theme
import qs.components

// The editor of the Theme setting: a sample of every theme (and of auto) in a wrapping row; a click picks it.
Item {
    id: editor

    property string value                 // the theme id in the form (draft or applied)
    property var options: []              // the ids the schema offers, in order
    signal changed(string id)

    implicitHeight: flow.implicitHeight

    // The sample entries in the order of `options`: themes from Tokens.themeList, plus a split sample for auto.
    function entries(): var {
        const list = Tokens.themeList
        const light = list.find(t => t.id === "light")
        const dark = list.find(t => t.id === "dark")
        return options.map(id => {
            if (id === "auto") return { id: "auto", name: "Auto", colors: { bg: light.bg, surface: light.surface, ink: light.ink, bg2: dark.bg, surface2: dark.surface }, pending: false }
            const t = list.find(x => x.id === id)
            return t ? { id: t.id, name: t.name, colors: t, pending: t.pending === true } : null
        }).filter(e => e !== null)
    }

    Flow {
        id: flow
        width: parent.width
        spacing: 12
        Repeater {
            model: editor.entries()
            delegate: ThemeSwatch {
                required property var modelData
                themeId: modelData.id
                label: modelData.name
                colors: modelData.colors
                selected: modelData.id === editor.value
                busy: modelData.pending
                onChosen: editor.changed(modelData.id)
            }
        }
    }
}
