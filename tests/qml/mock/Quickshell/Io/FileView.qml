import QtQuick
// Test double of Quickshell.Io FileView: reads `path` through a file XHR (needs
// QML_XHR_ALLOW_FILE_READ=1) when created and when `path` changes; writes stay in memory
// (`written` counts them), so a test never touches the disk.
QtObject {
    id: root

    property string path: ""
    property bool blockLoading: false
    property bool watchChanges: false
    property bool atomicWrites: false
    property bool printErrors: true
    property int written: 0

    signal loaded()
    signal loadFailed(int error)
    signal fileChanged()

    property string _text: ""
    property bool _ready: false

    function text(): string { return _text; }
    function setText(text: string): void { _text = text; written++; }
    function reload(): void { _load(); }
    function _load(): void {
        if (path === "") return;
        const x = new XMLHttpRequest();
        x.open("GET", "file://" + path, false);
        try { x.send(); } catch (e) { loadFailed(FileViewError.FileNotFound); return; }
        if (x.status === 200 || (x.status === 0 && x.responseText !== "")) { _text = x.responseText; loaded(); }
        else loadFailed(FileViewError.FileNotFound);
    }
    onPathChanged: if (_ready) _load()
    Component.onCompleted: { _ready = true; _load(); }
}
