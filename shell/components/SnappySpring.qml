// A SpringAnimation with the snappy spring of the motion catalogue (Motion.springs.snappy).
import QtQuick
import qs.core

SpringAnimation {
    spring: Motion.springs.snappy.spring
    damping: Motion.springs.snappy.damping
    mass: Motion.springs.snappy.mass
    epsilon: Motion.springs.snappy.epsilon
}
