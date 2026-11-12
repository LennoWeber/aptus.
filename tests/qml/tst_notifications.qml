// The Notifications and Progress services themselves (wave-2 review of S3, findings 4–8): a
// malformed image URL, the image copy (confirmed before use, reused on a replace), Clear all, the
// held summary's wording, a progress item's cancel action. Both are Quickshell Singletons: each
// test loads their text as an Item (as tst_theme does) against the mock import dir, with the
// notification server, Focus, Dnd, Hypr, Paths and execDetached replaced by the doubles below;
// SurfaceManager, Config and Tokens are the real ones.
import QtQuick
import QtTest
import qs.core

TestCase {
    id: testCase
    name: "notifications"

    // The doubles the loaded services read (see load()).
    property bool focusRunning: false
    property bool dndOn: false
    readonly property var paths: ({ test: true, notifCache: "/nonexistent-aptus-test/notif", notificationsState: "" })
    readonly property var hypr: ({ windowForApp: (entry, app) => null, focusWindow: address => {} })
    property var execs: []
    function exec(args: var): void { execs = execs.concat([args]); }
    property var progress: null
    property var notifications: null

    function load(file: string, replacements: var): var {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl("../../shell/services/" + file), false);
        xhr.send();
        let text = xhr.responseText.replace("pragma Singleton\n", "").replace("import Quickshell\n", "")
            .replace(/\nSingleton \{/, "\nItem {")
            .replace('import "js/notifications.js"', 'import "../../shell/services/js/notifications.js"');
        for (const r of replacements) text = text.replace(r[0], r[1]);
        return Qt.createQmlObject(text, testCase, file);
    }
    function loadNotifications(): var {
        return load("Notifications.qml", [
            ["import Quickshell.Services.Notifications\n", ""],
            [/NotificationServer \{[\s\S]*?\n    \}\n/, "QtObject { id: server; property var trackedNotifications: ({ values: [] }) }\n"],
            ["model: server.trackedNotifications", "model: []"],
            ["NotificationCloseReason.Dismissed", "2"],
            [/\bQuickshell\.execDetached\(/g, "testCase.exec("],
            [/\bFocus\.running\b/g, "testCase.focusRunning"],
            [/\bDnd\.on\b/g, "testCase.dndOn"],
            [/\bProgress\./g, "testCase.progress."],
            [/\bHypr\./g, "testCase.hypr."],
            [/\bPaths\./g, "testCase.paths."]
        ]);
    }
    function init() {
        SurfaceManager.locked = false;
        SurfaceManager.fullscreenMonitors = [];
        SurfaceManager.syncMonitors(["A"]);
        SurfaceManager.activeMonitor = "A";
        focusRunning = false;
        dndOn = false;
        execs = [];
        progress = load("Progress.qml", [[/\bNotifications\./g, "testCase.notifications."]]);
        notifications = loadNotifications();
        verify(notifications && progress);
    }
    function cleanup() {
        notifications.destroy();
        progress.destroy();
        notifications = progress = null;
        const m = SurfaceManager.monitors["A"];
        for (const e of m.passive.slice()) SurfaceManager.dismiss(e.id, "A");
    }

    // A live notification as Quickshell hands it (the fields _arrive reads).
    function live(id: int, extra: var): var {
        const n = { tracked: true, id: id, appName: "Mail", appIcon: "", desktopEntry: "", summary: "Hello " + id, body: "",
                    image: "", urgency: 1, resident: false, hasInlineReply: false, hints: {}, actions: [], dismissed: false };
        n.dismiss = () => { n.dismissed = true; };
        for (const k in extra) n[k] = extra[k];
        return n;
    }
    function record(id: int): var { return notifications.history.find(r => r.id === id) || null; }
    function toasts(): var { return SurfaceManager.monitors["A"].passive.filter(e => e.kind === "toast"); }
    // Finish an image copy job as the shell script would ("" = it failed).
    function finish(job: var, out: string): void {
        job.stdout.text = out;
        job.stdout.streamFinished();
    }

    function test_a_malformed_image_url_is_no_image() {
        notifications._arrive(live(5, { image: "file:///tmp/%E0%A4%A.png" }));
        verify(record(5) !== null, "the notification arrives");
        compare(record(5).image, "");
        verify(notifications._live[5] !== undefined, "and stays live");
        compare(notifications._copyJobs.length, 0);
        // Found by the e2e run: the toast showed the sender's URL as it was (a QML Image warning)
        compare(toasts().length, 1);
        compare(toasts()[0].payload.image, "", "the toast shows no image either");
    }

    function test_the_image_is_set_once_its_copy_is_confirmed() {
        notifications._arrive(live(6, { image: "file:///tmp/sender/cover%20art.png" }));
        compare(record(6).image, "", "no image before the copy is confirmed");
        compare(notifications._copyJobs.length, 1);
        const job = notifications._copyJobs[0];
        compare(job.source, "/tmp/sender/cover art.png");
        verify(job.command.indexOf(job.source) > 0 && job.command.indexOf(job.dst) > 0);
        verify(job.dst.indexOf(paths.notifCache + "/6-") === 0);
        finish(job, "ok\n1234 1700000000\n" + job.dst + "\n");
        compare(record(6).image, job.dst);
        compare(notifications._copyJobs.length, 0);
        // a failed copy (refused, gone, timed out) leaves no image
        notifications._arrive(live(7, { image: "/tmp/sender/huge.png" }));
        finish(notifications._copyJobs[0], "");
        compare(record(7).image, "");
    }

    // Found by the e2e test: Quickshell hands an image-path hint that is no file:// URL (a plain
    // path or an icon name) as image://icon/<hint>; a plain absolute path is still a file to copy.
    function test_a_plain_image_path_hint_is_copied() {
        notifications._arrive(live(9, { image: "image://icon//tmp/sender/plain.png" }));
        compare(notifications._copyJobs.length, 1);
        compare(notifications._copyJobs[0].source, "/tmp/sender/plain.png");
        finish(notifications._copyJobs[0], "ok\n5 6\n" + notifications._copyJobs[0].dst + "\n");
        verify(record(9).image.indexOf(paths.notifCache + "/9-") === 0);
        // an icon name and image-data are no file
        notifications._arrive(live(12, { image: "image://icon/dialog-information" }));
        notifications._arrive(live(13, { image: "image://qsimage/13/0" }));
        compare(notifications._copyJobs.length, 0);
        compare(record(12).image, "");
        compare(record(13).image, "");
    }

    function test_a_replace_reuses_the_copy() {
        notifications._arrive(live(8, { image: "/tmp/sender/a.png" }));
        const first = notifications._copyJobs[0];
        const dst = first.dst;
        // a replace while the copy runs starts no second copy
        notifications._arrive(live(8, { image: "/tmp/sender/a.png", summary: "again" }));
        compare(notifications._copyJobs.length, 1);
        finish(first, "ok\n10 20\n" + dst + "\n");
        compare(record(8).image, dst);
        // a replace afterwards shows the copy at once; its job only checks the source (known, stamp)
        notifications._arrive(live(8, { image: "/tmp/sender/a.png", summary: "third" }));
        compare(record(8).image, dst);
        compare(notifications._copyJobs.length, 1);
        const check = notifications._copyJobs[0];
        compare(check.known, dst);
        compare(check.stamp, "10 20");
        finish(check, "ok\n10 20\n" + dst + "\n");
        compare(record(8).image, dst);
        verify(!execs.some(a => a[0] === "rm"), "nothing deleted: " + JSON.stringify(execs));
        // the source changed (new stamp): a new copy replaces the old one, which is deleted
        notifications._arrive(live(8, { image: "/tmp/sender/a.png", summary: "fourth" }));
        const changed = notifications._copyJobs[0];
        finish(changed, "ok\n11 30\n" + changed.dst + "\n");
        compare(record(8).image, changed.dst);
        verify(execs.some(a => a[0] === "rm" && a[a.length - 1] === dst), "the old copy goes");
    }

    function test_clear_all_closes_toasts_progress_and_held() {
        notifications._arrive(live(10, { urgency: 2 }));                         // a critical toast
        notifications._arrive(live(11, { hints: { value: 40 } }));               // a progress item
        verify(toasts().length >= 1);
        compare(progress.items.length, 1);
        dndOn = true;
        notifications._arrive(live(12, {}));                                     // held by DND
        compare(notifications.held, 1);
        notifications.clearAll();
        compare(toasts().length, 0, "the cleared records' toasts close");
        compare(progress.items.length, 0, "their progress items go");
        compare(notifications.held, 0);
        compare(notifications.history.length, 0);
        dndOn = false;
        wait(50);
        compare(toasts().length, 0, "no summary of cleared notifications");
    }

    function heldSummary(): string {
        const e = SurfaceManager.monitors["A"].passive.find(x => x.key === "held");
        return e ? e.payload.summary : "";
    }
    function test_held_summary_follows_what_held_most() {
        focusRunning = true;
        notifications._arrive(live(20, {}));
        focusRunning = false;
        dndOn = true;                                         // focus ends, DND still holds
        for (const id of [21, 22, 23]) notifications._arrive(live(id, {}));
        compare(notifications.held, 4);
        compare(heldSummary(), "");
        dndOn = false;
        tryVerify(() => heldSummary() !== "");
        compare(heldSummary(), "4 notifications during Do not disturb");
        compare(notifications.held, 0);
    }
    function test_a_held_notification_closed_by_its_sender_is_not_summarised() {
        // the e2e pair fullscreen test → pinned card: a summary toast for a closed notification
        // covered the card after the fullscreen window left
        dndOn = true;
        notifications._arrive(live(25, {}));
        notifications._arrive(live(26, {}));
        compare(notifications.held, 2);
        notifications._senderClosed(25);
        compare(notifications.held, 1);
        notifications._senderClosed(26);
        compare(notifications.held, 0);
        dndOn = false;
        wait(50);
        compare(heldSummary(), "", "nothing left to summarise");
        // one left: the summary counts only that one
        dndOn = true;
        notifications._arrive(live(27, {}));
        notifications._arrive(live(28, {}));
        notifications._senderClosed(27);
        dndOn = false;
        tryVerify(() => heldSummary() !== "");
        compare(heldSummary(), "1 notification during Do not disturb");
    }
    function test_held_summary_when_focus_was_on_at_start() {
        notifications.destroy();
        focusRunning = true;
        notifications = loadNotifications();
        notifications._arrive(live(30, {}));
        notifications._arrive(live(31, {}));
        focusRunning = false;
        tryVerify(() => heldSummary() !== "");
        compare(heldSummary(), "2 notifications while you were focused");
    }

    // Wave-2 simplify A3: a toast entry that leaves without Notifications (the Notch's timeout,
    // rules.js expiry) is forgotten through SurfaceManager.passiveGone.
    function test_a_toast_gone_elsewhere_is_forgotten() {
        notifications._arrive(live(50, {}));
        const t = toasts()[0];
        compare(notifications._toasts[50], t.id);
        compare(notifications._stack.passiveId, t.id);
        SurfaceManager.dismiss(t.id, "A");
        compare(notifications._toasts[50], undefined);
        compare(notifications._stack, null);
        notifications._arrive(live(50, { summary: "again" }));      // replaces_id: a new toast
        compare(toasts().length, 1);
        verify(toasts()[0].id !== t.id);
        compare(notifications._toasts[50], toasts()[0].id);
    }
    function test_progress_cancel_invokes_the_senders_own_action() {
        let invoked = "";
        const n = live(40, { hints: { value: 25 },
                             actions: [{ identifier: "Cancel", text: "Cancel", invoke: () => { invoked = "Cancel"; } }] });
        notifications._arrive(n);
        compare(progress.items.length, 1);
        verify(progress.items[0].cancellable);
        progress.cancel("n:40");
        compare(invoked, "Cancel", "the app gets its own action id");
        compare(progress.items.length, 0);
    }
}
