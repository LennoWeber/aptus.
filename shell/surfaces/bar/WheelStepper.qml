// The wheel of one bar item (bar.js wheelSteps): feed each event's angleDelta.y and get whole
// notches back (+ = up); small deltas add up, a turn of direction drops the carry.
import QtQuick
import "js/bar.js" as B

QtObject {
    id: root

    // The delta carried to the next event.
    property real _carry: 0

    function feed(delta: real): int {
        const r = B.wheelSteps(root._carry, delta);
        root._carry = r.carry;
        return r.steps;
    }
}
