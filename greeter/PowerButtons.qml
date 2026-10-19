import QtQuick
import qs.models
import qs.components

// Restart and shut down. There is no sleep button on purpose.
Row {
    id: buttons

    signal actionRequested(int action)
    spacing: 10

    ActionButton { implicitHeight: 44; text: "Restart"; onClicked: buttons.actionRequested(Enums.PowerAction.Restart) }
    ActionButton { implicitHeight: 44; text: "Shut down"; onClicked: buttons.actionRequested(Enums.PowerAction.Shutdown) }
}
