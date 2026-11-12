// A SpringAnimation with the notch spring of the motion catalogue (Motion.springs.notch): the
// bulge's size (M-06) and a compact slot's width (M-05).
import QtQuick
import qs.core

SpringAnimation {
    spring: Motion.springs.notch.spring
    damping: Motion.springs.notch.damping
    mass: Motion.springs.notch.mass
    epsilon: Motion.springs.notch.epsilon
}
