.pragma library
// The notification logic of surfaces/notch.md §6 and 05-interaction §8, as pure functions over
// plain objects. Notifications.qml keeps the live Quickshell objects and calls these.
//
// A record (Today's history entry, newest first in Notifications.history):
//   { id: int (the server's id; injected ones count down from -1), appName, appIcon, desktopEntry,
//     summary, body (reduced markup: <b> <i> <a href>), image: url string | "",
//     urgency: 0 low | 1 normal | 2 critical, actions: [{ id, text }] (without "default"),
//     hasDefault: bool, resident: bool, reply: bool (inline-reply action), progress: -1 | 0..100,
//     time: ms since the epoch (arrival or last replace), read: bool, live: bool (the sender
//     still tracks it; actions work) }
//
// The policy context (what decides whether a toast shows, 05 §8):
//   { dnd: bool, focus: bool, fullscreen: bool (on the active monitor), overFullscreen:
//     "critical" | "none" | "all", allowlist: [app], muted: { app: until ms }, now: ms }
//
// A decision: { show: "toast" | "today" | "held" | "progress", priority: 0 | 2, reason:
//   "" | "dnd" | "focus" | "fullscreen" | "low" | "muted" }
//
// A toast payload (SurfaceManager.post("toast", payload, priority, monitor, "n:<id>")):
//   { nid: int (record id; 0 for a system toast), appName, appIcon, summary, body, image,
//     critical: bool, actions: [{ id, text }] (≤ toast.maxActions), hasDefault, resident, reply,
//     timeout: ms (0 = until dismissed), time, stack: null | { count, icons: [appIcon], apps:
//     [appName] }, opens: "" | "today" (a click opens Today: the stack and the held summary),
//     glyph: "" (a system toast's glyph instead of the app icon, e.g. "battery_alert") }
//
// The stack (notch.md §6 arrival rule 2): { passiveId, monitor, count, icons, apps, last: ms }.
