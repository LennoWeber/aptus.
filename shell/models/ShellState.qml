import QtQuick

// Global UI stage of the shell.
QtObject {
    property int stage           // Enums.Stage
    property int activeOverlay   // Enums.Overlay
    property int activeDropdown  // Enums.DropdownId
    property int activeTile      // Enums.TileId, the tile shown in detail view
    property bool barHidden      // bar auto-hidden in tablet mode, returns on swipe from top edge
    property bool blurActive     // background blur shown (control center, launcher)
    property bool debugTiming    // overlay with measured reaction times
    property real lastHotkeyToFrameMs  // measured: hotkey to first visible change

    // Open the dropdown under a bar item (Enums.DropdownId).
    function openDropdown(dropdownId: int): void {
        if (dropdownId === Enums.DropdownId.None) throw new Error("invariant: ShellState.openDropdown: openDropdown(None), use closeDropdown()")
        if (stage !== Enums.Stage.Closed && stage !== Enums.Stage.Dropdown) throw new Error("invariant: ShellState.openDropdown: dropdown opened while control center or detail is open")
        if (activeOverlay !== Enums.Overlay.None) throw new Error("invariant: ShellState.openDropdown: dropdown opened over an overlay (the launcher closes all dropdowns)")
        if (activeDropdown !== Enums.DropdownId.None && stage !== Enums.Stage.Dropdown) throw new Error("invariant: ShellState.openDropdown: a dropdown is active outside the dropdown stage")
        if (activeTile !== Enums.TileId.None && stage !== Enums.Stage.Detail) throw new Error("invariant: ShellState.openDropdown: a tile is active outside the detail stage")
        // The host anchors it under the clicked bar item; only one dropdown is open at a time.
        activeDropdown = dropdownId
        stage = Enums.Stage.Dropdown
    }

    function closeDropdown(): void {
        if (activeDropdown !== Enums.DropdownId.None && stage !== Enums.Stage.Dropdown) throw new Error("invariant: ShellState.closeDropdown: a dropdown is active outside the dropdown stage")
        if (activeTile !== Enums.TileId.None && stage !== Enums.Stage.Detail) throw new Error("invariant: ShellState.closeDropdown: a tile is active outside the detail stage")
        if (activeDropdown === Enums.DropdownId.None) return
        activeDropdown = Enums.DropdownId.None
        if (stage === Enums.Stage.Dropdown) stage = Enums.Stage.Closed
    }

    // Blur the background and show the tiles.
    function openControlCenter(): void {
        if (activeDropdown !== Enums.DropdownId.None && stage !== Enums.Stage.Dropdown) throw new Error("invariant: ShellState.openControlCenter: a dropdown is active outside the dropdown stage")
        if (activeTile !== Enums.TileId.None && stage !== Enums.Stage.Detail) throw new Error("invariant: ShellState.openControlCenter: a tile is active outside the detail stage")
        // The window is pre-loaded and only toggles visibility (feedback budget).
        // TODO(phase 7, polish): call reportHotkeyLatency when the first frame is visible.
        closeDropdown()
        activeTile = Enums.TileId.None
        stage = Enums.Stage.ControlCenter
        activeOverlay = Enums.Overlay.ControlCenter
        blurActive = true
    }

    // Grow a tile into its detail view (Enums.TileId).
    function openTile(tileId: int): void {
        if (tileId === Enums.TileId.None) throw new Error("invariant: ShellState.openTile: openTile(None)")
        if (stage !== Enums.Stage.ControlCenter && stage !== Enums.Stage.Detail) throw new Error("invariant: ShellState.openTile: tile opened outside control center")
        if (activeDropdown !== Enums.DropdownId.None && stage !== Enums.Stage.Dropdown) throw new Error("invariant: ShellState.openTile: a dropdown is active outside the dropdown stage")
        if (activeTile !== Enums.TileId.None && stage !== Enums.Stage.Detail) throw new Error("invariant: ShellState.openTile: a tile is active outside the detail stage")
        activeTile = tileId
        stage = Enums.Stage.Detail
    }

    // Control center directly in the notifications detail.
    function openNotifications(): void {
        throw new Error("not implemented")
    }

    // Enums.Overlay.
    function openOverlay(overlayId: int): void {
        if (overlayId < Enums.Overlay.None || overlayId > Enums.Overlay.WallpaperPicker) throw new Error("invariant: ShellState.openOverlay: unknown overlay id")
        if (overlayId === Enums.Overlay.None) {
            closeAll()
            return
        }
        // An overlay replaces everything else: dropdown, control center and detail close first.
        closeDropdown()
        activeTile = Enums.TileId.None
        stage = Enums.Stage.Closed
        activeOverlay = overlayId
        blurActive = overlayId === Enums.Overlay.Launcher || overlayId === Enums.Overlay.WallpaperPicker
    }

    // One step back: detail -> control center -> closed.
    function back(): void {
        if (activeDropdown !== Enums.DropdownId.None && stage !== Enums.Stage.Dropdown) throw new Error("invariant: ShellState.back: a dropdown is active outside the dropdown stage")
        if (activeTile !== Enums.TileId.None && stage !== Enums.Stage.Detail) throw new Error("invariant: ShellState.back: a tile is active outside the detail stage")
        // Same path for Esc and the touch back button: overlay -> closed, detail -> control center -> closed, dropdown -> closed.
        if (stage === Enums.Stage.Detail) {
            activeTile = Enums.TileId.None
            stage = Enums.Stage.ControlCenter
        } else if (activeOverlay !== Enums.Overlay.None || stage === Enums.Stage.ControlCenter) closeAll()
        else if (stage === Enums.Stage.Dropdown) closeDropdown()
    }

    function closeAll(): void {
        activeDropdown = Enums.DropdownId.None
        activeTile = Enums.TileId.None
        activeOverlay = Enums.Overlay.None
        stage = Enums.Stage.Closed
        blurActive = false
    }

    // Store a measured hotkey-to-frame time for the debug overlay.
    function reportHotkeyLatency(ms: real): void {
        if (!(ms >= 0)) throw new Error("invariant: ShellState.reportHotkeyLatency: negative or invalid latency")
        throw new Error("not implemented")
    }
}
