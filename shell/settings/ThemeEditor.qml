import QtQuick
import qs.theme
import qs.components

// The editor of the Theme setting: a sample of every theme (and of auto) in a wrapping row; a click picks it.
Item {
    id: editor

    property string value                 // the theme id in the form (draft or applied)
    property var options: []              // the ids the schema offers, in order
    // TODO(phase 7, themes): Flow of ThemeSample over the entries of `options` (themes from Tokens.themeList, a split light/dark sample for auto); implicitHeight from the Flow; a click emits changed(id).
    signal changed(string id)
}
