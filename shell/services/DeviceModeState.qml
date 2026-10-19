import QtQuick
import Quickshell
import Quickshell.Io

// Laptop / tablet state of the 2-in-1: the tablet switch, the orientation sensor and the screen rotation that follows it.
QtObject {
    id: root

    property bool tabletMode         // tablet switch reported by the device
    property bool touchActive        // last input came from the touchscreen (set by the surfaces that see touch)
    property int orientation         // Enums.Orientation, from the orientation sensor
    property bool autoRotate: true   // follow the sensor in tablet mode
    property bool rotationLocked     // user locked the current orientation
    property string output: "eDP-1"

    // Orientation of the screen as it is set now; laptop mode and a locked rotation never move it.
    readonly property bool following: tabletMode && autoRotate && !rotationLocked
    onFollowingChanged: if (!following && !rotationLocked) apply(tabletMode ? orientation : 0)
    onOrientationChanged: if (following) apply(orientation)

    function setRotationLocked(on: bool): void {
        rotationLocked = on
    }

    // Enums.Orientation values 0..3 equal the Hyprland transforms (normal, 90, 180, 270).
    property int applied
    function apply(transform: int): void {
        if (transform === applied) return
        applied = transform
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.monitor({ output = '" + root.output + "', mode = '1920x1080@60', position = '0x0', scale = '1', transform = " + transform + " })"])
    }

    // The tablet switch is read straight from the input device: the first one that reports SW_TABLET_MODE.
    // A tiny loop prints the state when it changes; nothing runs on a machine without the switch.
    property Process switchProbe: Process {
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", "python3", "-c", `
import fcntl, array, glob, os, sys, time
def find():
    for cap in glob.glob('/sys/class/input/event*/device/capabilities/sw'):
        try:
            if int(open(cap).read().split()[-1], 16) & 2:
                return '/dev/input/' + cap.split('/')[4]
        except Exception:
            pass
dev = find()
if not dev: sys.exit(0)
fd = os.open(dev, os.O_RDONLY)
last = None
while True:
    buf = array.array('B', [0] * 4)
    fcntl.ioctl(fd, (2 << 30) | (4 << 16) | (ord('E') << 8) | 0x1b, buf, True)
    now = 1 if buf[0] & 2 else 0
    if now != last:
        print('tablet', now, flush=True)
        last = now
    time.sleep(1)
`]
        stdout: SplitParser {
            onRead: line => root.tabletMode = line.trim() === "tablet 1"
        }
    }

    // iio-sensor-proxy through monitor-sensor: "=== Accelerometer orientation changed: left-up".
    property Process sensor: Process {
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", "monitor-sensor", "--accel"]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/orientation changed: (\S+)/) || line.match(/\(orientation: (\S+)/)
                if (!m) return
                const map = { "normal": 0, "left-up": 1, "bottom-up": 2, "right-up": 3 }
                if (m[1] in map) root.orientation = map[m[1]]
            }
        }
    }
}
