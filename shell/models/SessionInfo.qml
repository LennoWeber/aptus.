import QtQuick

// A session the greeter can start.
QtObject {
    property string id
    property string name             // e.g. "Hyprland"
    property string command         // command greetd starts after login
    property string iconName
}
