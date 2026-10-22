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

    // Where the shell colours come from (settings appearance.themeSource: "standard" | "fixed" | "wallpaper").
    // Standard is the neutral palette of theme/tokens.json, Fixed the built-in colours of the chosen style,
    // FromWallpaper the colours read from the picture. ("Neutral" is taken by Severity.)
    enum ThemeSource { Standard, Fixed, FromWallpaper }

    // How colours are softened (settings appearance.style: "watercolor" | "oil").
    enum ThemeStyle { Watercolor, Oil }

    // Colour of the top bar (settings bar.tone: "offwhite" | "tinted").
    enum BarTone { OffWhite, Tinted }
}
