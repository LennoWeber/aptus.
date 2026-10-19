pragma ComponentBehavior: Bound
import QtQuick
import qs.theme
import qs.components

// Editor for the list of web search engines: name and URL template per row, add and remove.
Column {
    id: editor

    property var engines: []   // { id, name, urlTemplate }
    signal changed(var engines)

    spacing: 8

    function update(index: int, key: string, value: string): void {
        const next = editor.engines.map(e => Object.assign({}, e))
        next[index][key] = value
        editor.changed(next)
    }

    Repeater {
        model: editor.engines
        delegate: Row {
            id: line
            required property var modelData
            required property int index
            spacing: 8
            FieldBox {
                width: 140
                text: line.modelData.name
                placeholder: "Name"
                onEdited: value => editor.update(line.index, "name", value)
            }
            FieldBox {
                width: 360
                text: line.modelData.urlTemplate
                placeholder: "https://example.com/?q={query}"
                onEdited: value => editor.update(line.index, "urlTemplate", value)
            }
            // At least one engine stays.
            ActionButton {
                implicitHeight: 34
                active: editor.engines.length > 1
                text: "Remove"
                onClicked: editor.changed(editor.engines.filter((e, i) => i !== line.index))
            }
        }
    }

    ActionButton {
        implicitHeight: 34
        text: "Add search engine"
        onClicked: editor.changed(editor.engines.concat([{ id: "custom-" + Date.now(), name: "", urlTemplate: "" }]))
    }
    Label {
        text: "Use {query} where the search words go."
        color: Tokens.inkFaint
    }
}
