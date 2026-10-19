import QtQuick

// Pick the user.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): remembers the last user; a single user is shown without a picker.

    property var users
    property string selectedUser
    signal userSelected(string userName)
}
