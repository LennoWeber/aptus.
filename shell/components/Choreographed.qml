// Base of NotchMode and Drawer: the content choreography of 04 §3 rule 1. The host moves the
// geometry from t = 0; the content fades in from Motion.contentDelay over `fade`, rising
// Motion.contentRise px (`enter`), and on exit fades out first over Motion.exitContentFade (`exit`).
// Reduced motion: a plain crossfade, no delay and no rise (04 §7).
import QtQuick
import qs.core

Item {
    id: root

    // Whether the content is shown; the subtype binds it (NotchMode: active, Drawer: open).
    property bool shown: true
    // False for the surface that is not the hero (04 §3 rule 8): it changes without choreography.
    property bool choreographed: true

    property bool _entered: false
    Component.onCompleted: _entered = true

    opacity: 0
    transform: Translate { id: shift; y: Motion.reduced ? 0 : Motion.contentRise }

    states: State {
        name: "shown"
        when: root.shown && root._entered
        PropertyChanges { root.opacity: 1; shift.y: 0 }
    }
    transitions: [
        Transition {
            to: "shown"
            enabled: root.choreographed
            SequentialAnimation {
                PauseAnimation { duration: Motion.reduced ? 0 : Motion.contentDelay }
                ParallelAnimation {
                    NumberAnimation {
                        target: root; property: "opacity"; duration: Motion.ms("fade", false)
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.enter
                    }
                    NumberAnimation {
                        target: shift; property: "y"; duration: Motion.ms("fade", false)
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.enter
                    }
                }
            }
        },
        Transition {
            from: "shown"
            enabled: root.choreographed
            NumberAnimation {
                targets: [root, shift]; properties: "opacity,y"
                duration: Motion.reduced ? Motion.reducedCrossfade : Motion.exitContentFade
                easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.exit
            }
        }
    ]
}
