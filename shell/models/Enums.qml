pragma Singleton
import QtQuick

// Shared enumerations. Structure only, no behaviour.
QtObject {
    // The three stages of the shell UI: dropdown -> control center -> detail.
    enum Stage { Closed, Dropdown, ControlCenter, Detail }

    // Modes of the launcher pill.
    enum LauncherMode { Apps, Web, Settings, Ai, Clipboard }

    // Full-screen overlays on the blurred background.
    enum Overlay { None, Launcher, ControlCenter, WallpaperPicker }

    // Bar items that can open a dropdown.
    enum DropdownId { None, Audio, Network, Bluetooth, Battery, NightLight, Clock }

    // Tiles in the control center; each can grow into a detail view.
    enum TileId {
        None, Calendar, Media, Network, Bluetooth, Caffeine, Audio, Display,
        AiUsage, Notifications, Focus, PowerProfile, Timer, Weather,
        SystemMonitor, Capture, Vpn, Hotspot
    }

    enum PowerMode { Saver, Balanced, Performance }

    // Session power actions. Suspend and hibernate are deliberately NOT part of aptus.
    enum PowerAction { Lock, Logout, Restart, Shutdown }

    // Screen orientation (auto-rotate in tablet mode).
    enum Orientation { Landscape, Portrait, LandscapeFlipped, PortraitFlipped }

    // Screen edge the launcher docks to in AI mode.
    enum DockEdge { Right, Left, Bottom }

    // Phases of applying settings from the settings app.
    enum ApplyPhase { Clean, Unsaved, AwaitingConfirm, Reverted }

    // Kinds of entries in the settings app.
    enum SettingKind {
        Toggle, Choice, Text, Number, Slider, Action, List,
        ProviderList, HotkeyList, KeyMap, TileList, Location
    }

    enum TimerMode { Timer, Pomodoro }

    // Functional colour: neutral by default, colour only signals state.
    enum Severity { Neutral, Ok, Warn, Critical }

    // What the context zone in the bar can show.
    enum ContextKind { WindowTitle, Media, Timer, Download, BatteryAlert, Notification }

    // Kind of an entry in launcher results.
    enum ResultKind { App, Window, Action, Setting, WebSuggestion, Calculation, ChatMessage, CliSession, ClipboardItem }

    // Type roles for Label.
    enum TextRole { Body, Bar, Title, Display, Mono }

    // Kinds of on-screen indicators.
    enum OsdKind { Volume, Brightness, Microphone, Rotation, Caffeine }

    // Screen edges (edge swipes).
    enum Edge { Top, Left, Right, Bottom }

    // How the wallpaper is placed on the screen (setting wallpaper.fit: "fill" | "fit" | "stretch" | "center" | "tile").
    // Fill covers the screen and crops, Fit shows the whole picture with bars in the theme colour, Stretch ignores the
    // aspect ratio, Center keeps the picture's size, Tile repeats it.
    enum WallpaperFit { Fill, Fit, Stretch, Center, Tile }

    // The stages of the island: a small pill at rest, one line of news, the on-screen indicator, the opened
    // island (its content is Enums.IslandView).
    enum IslandStage { Rest, Alert, Osd, Open }

    // What the opened island shows (Home is the overview with music, workspaces and status icons).
    enum IslandView { Home, Power, Screenshot, Clipboard, Emoji, Wallpaper }

    // Where the island grows to while the launcher or the control center takes the stage (None = it stays itself).
    enum MorphTarget { None, Launcher, ControlCenter }
}
