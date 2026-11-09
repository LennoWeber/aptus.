pragma Singleton
pragma ComponentBehavior: Bound
// Wallpaper: wallpaper.json, resolution per monitor.
// Owner: S1 (resolution, drawing; built), S10 (gallery, thumbnails, analysis, rotation).
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs.core

Singleton {
    id: root

    // the parsed wallpaper.json
    property var state: ({})
    // images in wallpaper.dir, newest first: [{ path, mtime }]
    property var images: []
    // monitor name → path shown as a live preview (gallery), overrides resolution
    property var preview: ({})
    // chroma-weighted hue of the active monitor's image, -1 unknown (S10)
    property real hue: -1
    // mean OKLab lightness, -1 unknown (S10)
    property real lightness: -1

    // mean OKLCH chroma of the image, -1 unknown (S10; wallpaper.md §5)
    property real chroma: -1

    // The image a monitor shows (wallpaper.md §3): the gallery preview, else monitors[name], byMode,
    // all, the newest image in wallpaper.dir, else "" (plain ground).
    function pathFor(monitor: string): string {
        const st = state || {};
        if (preview[monitor]) return preview[monitor];
        if (st.monitors && st.monitors[monitor]) return st.monitors[monitor];
        if (st.byMode && st.byMode[Tokens.mode]) return st.byMode[Tokens.mode];
        if (st.all) return st.all;
        return images.length ? images[0].path : "";
    }
    // Set the wallpaper of one monitor, or of every monitor when monitor is "" (IPC `wallpaper set`;
    // own images of single monitors are dropped then).
    function set(path: string, monitor: var): void {
        const st = JSON.parse(JSON.stringify(state || {}));
        const p = Paths.expand(String(path));
        if (monitor) { st.monitors = st.monitors || {}; st.monitors[String(monitor)] = p; }
        else { st.all = p; st.monitors = {}; }
        _write(st);
    }
    // The next image in wallpaper.dir after `all` (IPC `wallpaper next`, Spotlight "Next
    // wallpaper"): like a rotation step it changes `all` only, monitors with their own image keep
    // it (wallpaper.md §6; the shuffled rotation order is S10's).
    function next(): void {
        if (!images.length) return;
        const st = JSON.parse(JSON.stringify(state || {}));
        const i = images.findIndex(im => im.path === (st.all || images[0].path));
        st.all = images[(i + 1) % images.length].path;
        _write(st);
    }
    // Store and persist wallpaper.json (FileView creates a missing folder itself).
    function _write(st: var): void {
        st.v = 1;
        state = st;
        stateView.setText(JSON.stringify(st, null, 2) + "\n");
    }

    // wallpaper.dir, expanded (the folder FolderListModel watches).
    readonly property string _dir: Config.loaded ? Paths.expand(Config.get("wallpaper.dir")) : ""

    FileView {
        id: stateView
        path: Paths.wallpaperState
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.state = JSON.parse(text()); } catch (e) { Log.warn("service.wallpaper", "wallpaper.json: " + e); }
        }
    }
    // wallpaper.dir, watched (wallpaper.md §6), newest first: the first start shows the newest
    // image (§3); `images` follows every change.
    FolderListModel {
        id: folder
        folder: root._dir !== "" ? Paths.url(root._dir) : ""
        showDirs: false
        caseSensitive: false
        sortField: FolderListModel.Time
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.avif"]
        onCountChanged: root._list()
        onStatusChanged: root._list()
    }
    // images ← the folder model, newest first.
    function _list(): void {
        const out = [];
        for (let i = 0; i < folder.count; i++)
            out.push({ path: String(folder.get(i, "filePath")), mtime: folder.get(i, "fileModified").getTime() });
        images = out;
    }
}
