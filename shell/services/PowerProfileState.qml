import QtQuick
import Quickshell
import Quickshell.Services.UPower as UP
import qs.models

// Power profile (power-profiles-daemon).
Scope {
    id: root

    // Enums.PowerMode { Saver, Balanced, Performance } on the Quickshell enum { PowerSaver, Balanced, Performance }.
    property int profile: {
        switch (UP.PowerProfiles.profile) {
        case UP.PowerProfile.PowerSaver: return Enums.PowerMode.Saver
        case UP.PowerProfile.Performance: return Enums.PowerMode.Performance
        default: return Enums.PowerMode.Balanced
        }
    }
    property var availableProfiles: UP.PowerProfiles.hasPerformanceProfile
        ? [Enums.PowerMode.Saver, Enums.PowerMode.Balanced, Enums.PowerMode.Performance]
        : [Enums.PowerMode.Saver, Enums.PowerMode.Balanced]

    property int wanted: -1

    // Enums.PowerMode.
    function setProfile(newProfile: int): void {
        if (newProfile < Enums.PowerMode.Saver || newProfile > Enums.PowerMode.Performance) throw new Error("invariant: PowerProfileState.setProfile: unknown profile")
        if (newProfile === Enums.PowerMode.Performance && !UP.PowerProfiles.hasPerformanceProfile) throw new Error("invariant: PowerProfileState.setProfile: performance profile not available on this machine")
        wanted = newProfile
        UP.PowerProfiles.profile = newProfile === Enums.PowerMode.Saver ? UP.PowerProfile.PowerSaver
            : newProfile === Enums.PowerMode.Performance ? UP.PowerProfile.Performance : UP.PowerProfile.Balanced
        // If the daemon did not take the direct write, ask it through its command line tool.
        verify.restart()
    }

    Timer {
        id: verify
        interval: 500
        onTriggered: {
            if (root.wanted < 0 || root.profile === root.wanted) return
            console.log("aptus: power profile did not change by property, using powerprofilesctl")
            Quickshell.execDetached(["powerprofilesctl", "set", ["power-saver", "balanced", "performance"][root.wanted]])
        }
    }
}
