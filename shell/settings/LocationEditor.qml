pragma ComponentBehavior: Bound
import QtQuick
import qs.theme
import qs.components

// Weather location: search a place by name (Open-Meteo geocoding), tap a result to use it.
Column {
    id: editor

    property var weather: ({})   // the weather settings object
    signal changed(var weather)

    property var results: []
    property string status

    spacing: 10

    function search(): void {
        const name = field.text.trim()
        if (name === "") return
        status = "Searching…"
        results = []
        const request = new XMLHttpRequest()
        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE) return
            if (request.status !== 200) { editor.status = "Search failed (no connection?)"; return }
            const found = JSON.parse(request.responseText).results || []
            editor.results = found.map(r => ({ name: r.name, detail: [r.admin1, r.country].filter(x => x).join(", "), latitude: r.latitude, longitude: r.longitude }))
            editor.status = found.length === 0 ? "No place found" : ""
        }
        request.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=5&language=en&name=" + encodeURIComponent(name))
        request.send()
    }

    Label {
        text: "Now: " + (editor.weather.locationName || "none") + "  (" + Number(editor.weather.latitude).toFixed(2) + ", " + Number(editor.weather.longitude).toFixed(2) + ")"
        color: Tokens.inkSoft
    }

    Row {
        spacing: 8
        FieldBox { id: field; width: 280; placeholder: "City name"; onAccepted: editor.search() }
        ActionButton { implicitHeight: 34; text: "Search"; onClicked: editor.search() }
    }

    Label { visible: editor.status !== ""; text: editor.status; color: Tokens.inkFaint }

    Repeater {
        model: editor.results
        delegate: Item {
            id: hit
            required property var modelData
            width: 380
            height: 38
            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Tokens.ink
                opacity: tap.pressed ? 0.12 : tap.containsMouse ? 0.06 : 0
                Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
            }
            Label {
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                text: hit.modelData.name + (hit.modelData.detail ? "  ·  " + hit.modelData.detail : "")
            }
            MouseArea {
                id: tap
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    editor.changed(Object.assign({}, editor.weather, { locationName: hit.modelData.name, latitude: hit.modelData.latitude, longitude: hit.modelData.longitude }))
                    editor.results = []
                    field.text = ""
                }
            }
        }
    }
}
