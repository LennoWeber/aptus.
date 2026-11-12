pragma ComponentBehavior: Bound
// A file the shell reads and follows (07 §8): a FileView that also sees the file appear, be
// replaced or come back, even when its folder (or folders above it) did not exist at load.
// FileView watches the file and its folder only if the folder existed when the watch was set;
// while the folder is missing, a second FileView watches the missing folder's place in the
// nearest existing ancestor, and the watch is set again once the folder is there.
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // Absolute path of the file ("" = none).
    property string path: ""
    // As FileView: load synchronously; write through a temporary file and a rename.
    property bool blockLoading: false
    property bool atomicWrites: false
    // ms to gather a burst of changes into one reload (0: reload on every change).
    property int debounce: 0

    // As FileView: the file was read (text()), could not be read (FileViewError), was written.
    signal loaded()
    signal loadFailed(int error)
    signal saved()

    function text(): string { return _view.text(); }
    function setText(text: string): void { _view.setText(text); }
    function reload(): void { _view.reload(); }

    // Found by the probe (A6): FileView reports a folder as NotAFile and a missing path as
    // FileNotFound; setting watchChanges again re-reads which folders exist.
    // The folder of `path`.
    readonly property string _dir: _parent(path)
    // The walk up from _dir: the level being checked and its missing child ("" while _level is
    // _dir itself).
    property string _level: ""
    property string _child: ""
    // The view's watch was set while _dir existed (assumed until the walk finds a missing level).
    property bool _armed: true

    function _parent(p: string): string {
        const i = p.lastIndexOf("/");
        return i > 0 ? p.slice(0, i) : "/";
    }
    // Start the walk at the file's folder (the file is missing).
    function _walk(): void {
        _waiter.path = "";
        _child = "";
        if (path !== "") _check(_dir);
    }
    function _check(level: string): void {
        _level = level;
        if (_probe.path === level) _probe.reload(); else _probe.path = level;
    }
    function _missing(): void {
        _armed = false;
        if (_level === "/") return;
        _child = _level;
        _check(_parent(_level));
    }
    function _found(): void {
        if (_child !== "") { _waiter.path = _child; return; }      // wait for it to appear
        if (_armed) return;                                         // the view's watch covers _dir
        _armed = true;
        _view.watchChanges = false;
        _view.watchChanges = true;
        _view.reload();
    }
    onPathChanged: { _armed = true; _waiter.path = ""; }

    readonly property FileView _view: FileView {
        path: root.path
        blockLoading: root.blockLoading
        atomicWrites: root.atomicWrites
        watchChanges: true
        printErrors: false
        onFileChanged: if (root.debounce > 0) root._burst.restart(); else reload()
        onLoaded: { root._waiter.path = ""; root.loaded(); }
        onLoadFailed: error => {
            // later, not from inside the view's own signal: the walk may reload it
            if (error === FileViewError.FileNotFound) Qt.callLater(root._walk);
            root.loadFailed(error);
        }
        onSaved: root.saved()
    }
    readonly property FileView _probe: FileView {
        blockLoading: true
        printErrors: false
        onLoaded: Qt.callLater(root._found)
        onLoadFailed: error => Qt.callLater(error === FileViewError.FileNotFound ? root._missing : root._found)
    }
    readonly property FileView _waiter: FileView {
        watchChanges: true
        printErrors: false
        onFileChanged: Qt.callLater(root._walk)
    }
    readonly property Timer _burst: Timer {
        interval: root.debounce
        onTriggered: root._view.reload()
    }
}
