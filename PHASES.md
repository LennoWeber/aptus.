# PHASES.md – Projekt „aptus" (sichtbarer Name in der Shell: „shell.“)

Aktuelle Phase: **7 – Implementierung, alle geplanten Abschnitte gebaut (7a bis 7d), Durchgang gemacht; jetzt Gebrauch im Alltag und Feinschliff nach Lennos Rückmeldung**

Zweiter Phasenablauf (neue Funktion „Notch“, ab 22. Okt.): **Phase 1 (Plan) geschrieben, wartet auf Lennos Entscheidungen**, siehe Abschnitt „Notch“ weiter unten.

Dritter Phasenablauf (neue Funktion „Bild-Theming“, 22. Okt.): **Phase 1 bis 4 erledigt, wartet auf „weiter“ für Phase 5**, siehe Abschnitt „Bild-Theming“ weiter unten.

## Ziel

Eine komplette, eigenständige Desktop-Shell für **Fedora + Hyprland** (1920x1080), die professionell aussieht, sich ruhig und hochwertig anfühlt und gestalterisch eigene Wege geht. Am Ende: öffentliches GitHub-Repo mit Installer. UI-Sprache: Englisch.

Vorgaben des Nutzers (verbindlich):
- Oben eine kompakte Leiste (28 px): dünn und funktional.
- Light Mode als Standard, im Alltag mit Night Light.
- Aussehen und Gefühl fast wichtiger als der Funktionsumfang.
- Eigene Ideen, keine Orientierung an bestehenden Projekten.
- Farbe nur funktional (Zustände), Palette sonst neutral.
- Kein Liquid Glass, Leiste und Dropdowns undurchsichtig.
- Sofortiges Feedback nach jedem Hotkey.

## Konzept

### Stufenmodell
1. **Dropdown:** Klick auf ein Leistenelement (z. B. WLAN) öffnet ein macOS-artiges Dropdown unter dem Symbol mit den Schnelleinstellungen. Undurchsichtig, kompakt.
2. **Control Center:** Geblurrter Hintergrund, mehrere Kacheln. Klick auf eine Kachel lässt sie mittig auf die gesamte Fläche wachsen (Detail).
3. **Esc geht immer einen Schritt zurück:** Detail → Control Center → geschlossen. Gilt auch für Launcher und Wallpaper Picker.

### Leiste
28 px, bündig am Rand. Links Workspaces, Mitte Kontext-Zone (Fenstertitel, Musik, Timer, Download, Akku-Warnung; wechselt per Übergang), rechts Status-Gruppe (Audio, Netz, Bluetooth, Akku, Nachtlicht, Uhr).

### Kacheln des Control Centers
Alle gewünscht. Pflicht (zuerst): **Calendar** (Google Calendar), **Network**, **Bluetooth**, **Caffeine**, **Media**.
Danach: Audio, Display (Helligkeit + Night Light), Focus/Do-not-disturb, Power Profile, AI usage, Timer/Pomodoro, Weather, System Monitor, Capture (Screenshot/Aufnahme), VPN, Hotspot, Notifications.
- **Caffeine:** nur manuell. Ändert sich ausschließlich, wenn der Nutzer klickt. Kein Timer, kein Auto-Aus.
- **Calendar:** zuerst per privater iCal-Adresse (nur lesen), später optional Google-Anmeldung (OAuth).

### Launcher „Modus-Pille"
- Abgerundete Suchleiste auf geblurrtem Hintergrund (gleicher Blur wie Control Center).
- Modi: Apps, Web, Settings, AI, Clipboard.
- **Startet immer im Apps-Modus** (einstellbar, Standard Apps).
- Innerhalb der Pille wechselt man mit **Ctrl + 1..5** (1 Apps, 2 Web, 3 Settings, 4 AI, 5 Clipboard), Tab schaltet zusätzlich durch.
- Web, Settings und Clipboard haben je einen eigenen globalen Hotkey, der direkt in den Modus springt (siehe Tabelle). Gleicher Hotkey bei offenem Modus schließt.
- Die anderen Modi schweben als Symbole am Ende der Pille; beim Wechsel verschmilzt das Symbol des neuen Modus mit der Pille, die übrigen rücken nach.
- Leerer Zustand: fast leer, optional zuletzt genutzte Apps und offene Fenster (wird getestet, ggf. gestrichen).
- Spezialfälle in derselben Zeile: Rechnen, Timer, Systemaktionen.
- Verschmelzen: erst einfache Variante (Gleiten + Überblenden), Shader-Tropfen als Prototyp in Phase 5.
- **Web-Modus (Zen):** Läuft Zen, öffnet die Suche in einem neuen Tab und Hyprland wechselt zum Workspace des Browsers. Läuft er nicht, startet Zen und zeigt die Suche. Suchmaschine Standard Google, in den Settings änderbar.
- **AI-Modus dockt am Rand an:** Beim Wechsel in den AI-Modus (oder direkt mit Mod + A) wandert die Pille animiert an den rechten Bildschirmrand und wird dort zu einem schmalen Seitenpanel (ca. 420 px breit, Höhe unter der Leiste; Seite einstellbar rechts/links/unten). Das Panel kann eine Frage beantworten und Rückfragen zulassen, mehr nicht: keine Werkzeuge, kein Verlauf nach dem Schließen. Der Blur verschwindet, damit man Dinge auf dem Bildschirm nachlesen kann. Der Rest des Bildschirms bleibt bedienbar. Beim Wechsel in einen anderen Modus geht die Pille zurück in die Mitte, und der Blur kehrt zurück.
- **AI-Modus (Mod + A):** nur für kurze Fragen. Eine Frage rein, Antwort in der Pille, beim Schließen ist der Verlauf weg. Echte Coding-Sessions laufen im Terminal.
- **CLIs aus dem App-Launcher:** Claude (`claude`), Antigravity (`agy`) und Mistral (`vibe`) erscheinen als Einträge im Apps-Modus und starten die jeweilige CLI im Terminal. Neue Anbieter werden in `config/ai-providers.json` ergänzt, ohne Codeänderung.
- Entscheidung: AI bleibt eigener Modus und wird nicht Teil der Web-Suche. Der Kurzbefehl `/ai` entfällt. Anbieterwechsel im AI-Modus mit Alt + Pfeil links/rechts.
- Anbieter lassen sich auch in der Settings-App hinzufügen (mit Test-Knopf für den Befehl). Mitgelieferte Anbieter können deaktiviert, aber nicht gelöscht werden, eigene liegen in der Benutzerkonfiguration.

### Settings-App
Viel Anpassbarkeit, ohne dass es unübersichtlich wird. Prinzipien:
- Gute Standardwerte, sodass man nie etwas einstellen muss.
- 10 Kategorien in einer Seitenleiste: Appearance, Bar, Launcher, AI, Calendar & Weather, Control Center, Notifications, Shortcuts, System, About & Backup.
- Seltene Einstellungen sind als „advanced" markiert und standardmäßig ausgeblendet („Show advanced").
- Suche ist immer oben. Der Launcher-Modus Settings (Mod + S) durchsucht dieselben Einträge und springt mit Enter direkt zum Eintrag.
- Eigenes Fenster (entschieden).
- **Speichern mit Rückfrage, für alle Einstellungen:** Änderungen sind zunächst Entwurf. Ein Speichern-Knopf wendet sie an. Danach hat man 15 Sekunden, sie zu bestätigen. Ohne Bestätigung werden die alten Werte wiederhergestellt.
- Nach dem automatischen Zurücksetzen bleiben die eigenen Änderungen als ungespeicherter Entwurf im Fenster stehen (man verliert nichts). Ein Knopf „Discard changes" setzt den Entwurf auf die tatsächlich gültigen Werte zurück.
- Sicherung gegen Aussperren: Vor dem Anwenden entsteht ein Snapshot. Ein Hilfsprozess außerhalb der Shell stellt ihn nach 15 Sekunden wieder her, falls keine Bestätigung kommt, auch wenn die Shell hängt oder abstürzt. Der Bestätigungsknopf ist per Maus erreichbar, falls Tastenkürzel nicht mehr funktionieren.
- Geänderte Werte sind markiert und lassen sich einzeln auf den Standard zurücksetzen.
- Export/Import der Einstellungen, Zurücksetzen mit Rückfrage.
- Beschreibung: `config/settings-schema.json` (Kategorien, Einträge, Art), Werte: `config/settings.json`, Tastenkürzel: `config/hotkeys.json`. Die Settings-App ändert Tastenkürzel, der Installer erzeugt daraus die Hyprland-Binds.
- Eigene Änderungen liegen später in `~/.config/aptus/`, die Standardwerte im Repo bleiben unberührt.

### Hotkeys (Mod = Super)

| Hotkey | Aktion |
|---|---|
| Mod + D | Launcher (Apps) |
| Mod + B | Zen einfach öffnen (bleibt wie in deiner `hyprland.lua`, kein aptus-Bind; du erreichst damit deine Essentials) |
| Mod + Shift + B | Launcher direkt im Web-Modus (Browser-Suche) |
| Mod + S | Launcher direkt im Settings-Modus |
| Mod + A | Launcher direkt im AI-Modus (kurze Fragen) |
| Mod + Shift + C | Clipboard-Verlauf (Launcher im Clipboard-Modus) |
| Mod + C | Control Center |
| Mod + N | Control Center direkt in der Notifications-Ansicht |
| Mod + W | Wallpaper Picker |
| Mod + E | File Explorer |
| Mod + Enter | Terminal |
| Mod + Shift + S | Screenshot |
| Mod + 1, 2, 3, … | Workspaces wechseln |
| Funktionstasten | Lautstärke, Helligkeit usw. (Hardware, Shell zeigt nur die Bildschirmanzeige) |
| Esc | Einen Schritt zurück / schließen |
| Ctrl + 1..5 | Modus in der offenen Pille wechseln |

Alle fünf Modi haben damit einen direkten Hotkey: Mod + D (Apps), Mod + Shift + B (Web), Mod + S (Settings), Mod + A (AI), Mod + Shift + C (Clipboard).

### Lockscreen und Greeter (Login)
- **Lockscreen:** eigener, in Quickshell gebaut (Wayland-Session-Lock mit PAM-Anmeldung), damit er genau wie der Rest aussieht. Geblurrtes Hintergrundbild, große Uhr, das Passwortfeld ist eine Pille (gleiche Formensprache wie der Launcher). Benachrichtigungsinhalte sind standardmäßig verborgen. Die Sperre löst aptus selbst aus (Quickshell `IdleMonitor`); dein vorhandenes hypridle bleibt als Rückfall, falls eine andere Shell läuft.
- **Kein Sleep, kein Hibernate (verbindlich):** aptus löst nie Suspend oder Hibernate aus (HP Envy x360 hat damit Probleme unter Linux). Nach 5 Minuten Inaktivität wird der Bildschirm gesperrt, nach 10 Minuten geht er aus (beides einstellbar, 0 = nie). Gesperrt wird immer vor dem Ausschalten. Das Power-Menü kennt nur Lock, Log out, Restart, Shutdown. hypridle bekommt keinen Suspend-Eintrag, auch Greeter und Lockscreen zeigen keinen Sleep-Knopf. Caffeine hält nur Sperre und Bildschirm-Aus an.
- **Klappe zu:** Fedora lässt beim Schließen des Deckels (logind) normalerweise suspendieren. Entschieden: Deckel schließen sperrt nur den Bildschirm. Auf dem Laptop gilt das schon (`50-hp-sleep.conf`, `HandleLidSwitch=ignore`); der Installer prüft das nur und schreibt nichts nach `/etc/systemd`. Das Sperren beim Deckel-Schalter übernehmen Hyprland oder die Shell.
- **Greeter:** eigener Login-Bildschirm für greetd, ebenfalls Quickshell, im selben Stil: Benutzer, Session (Hyprland), Passwortpille, Ein-/Ausschalten. Einstellungen liegen systemweit in `/etc/aptus/greeter.json`, weil der Greeter vor jeder Sitzung läuft.
- **Sicherheit zuerst:** Stürzt die Shell beim Sperren ab, bleibt der Bildschirm in Hyprland gesperrt (kein Zugriff), das ist gewollt. greetd läuft auf dem Laptop schon, aktuell mit dem Greeter `noctalia-greeter-session` (VT 1, Benutzer `greetd`, Start mit `--session Hyprland`). Eine Vorlage für den Wechsel liegt in `config/greetd/config.toml`. Der Installer sichert `/etc/greetd/config.toml`, bevor er etwas ändert, und fragt nach, der alte Greeter bleibt als Rückweg erhalten (zusätzlich per Konsole/TTY dokumentiert). Kein Fingerabdrucksensor, nur Passwort.

### Touch und Tablet-Modus (HP Envy x360)
Der Laptop wird ab und zu als Tablet benutzt. Deshalb gelten von Anfang an diese Regeln:
- Alles ist auch per Touch erreichbar, nichts hängt an Hover oder nur an der Tastatur.
- Jede Fläche hat mindestens 40 px Trefferfläche, auch wenn sie optisch kleiner ist (die 28 px hohe Leiste bleibt optisch schlank, ihre Treffer sind größer).
- Zurück-Knopf überall, wo Esc zurückgeht (Detail → Control Center → geschlossen).
- Der Tablet-Modus wird hauptsächlich zum Lesen genutzt, eine Bildschirmtastatur ist nicht installiert. Version 1 setzt deshalb keine voraus.
- **Nie ausgesperrt:** Lockscreen und Greeter bekommen eine eingebaute kleine Tastatur, die im Tablet-Modus oder nach einer Berührung erscheint (einstellbar). Sonst käme man im Tablet-Modus nach der Sperre nicht mehr herein.
- **Lesen ohne Sperre:** Ein Fenster im Vollbild (Lesen, Video) hält Sperre und Bildschirm-Aus an (einstellbar, Standard an). Für Lesen im Fenster hilft Caffeine.
- Für andere Textfelder (Launcher, Settings) kann später optional eine System-Bildschirmtastatur dazukommen. Ist keine installiert, passiert nichts. Welche Pakete es für Fedora gibt, wird in Phase 3 geprüft.
- Der Tablet-Schalter des Geräts wird ausgelesen (`DeviceModeState.tabletMode`).
- **Randwischen (entschieden):** Wischen vom oberen Rand öffnet das Control Center, vom linken Rand den Launcher. Einstellbar und abschaltbar.
- **Leiste im Tablet-Modus (entschieden):** Sie verschwindet automatisch, damit mehr Platz zum Lesen bleibt, und kommt per Wischen vom oberen Rand zurück. Einstellbar.
- **Automatisches Drehen (entschieden):** Im Tablet-Modus folgt der Bildschirm dem Lagesensor (z. B. Hochformat zum Lesen). Dazu ein Dreh-Schalter im Control Center, der die Ausrichtung festhält. Einstellbar.

### Grundprinzip: Sofortiges Feedback
- Erste sichtbare Reaktion max. ca. 50 ms nach dem Tastendruck.
- Launcher, Control Center, Dropdowns werden vorab geladen und nur ein-/ausgeblendet.
- Animationen starten im selben Frame (140 ms klein, 260 ms groß).
- Zwischengespeicherte Daten sofort, neue asynchron. Nichts blockiert den UI-Thread.
- Effekte werden gemessen und vereinfacht oder gestrichen, wenn sie Flüssigkeit kosten.
- Debug-Modus mit Messanzeige der Reaktionszeit (`ShellState.debugTiming`).

### Look
Warmes Off-White (Tag) / Elfenbein (Night), Tinte statt Schwarz, Haarlinien statt Schatten, Tiefgrün als `ok`, Bernstein `warn`, Rot `critical`. Inter + JetBrains Mono. Eine Easing-Kurve, zwei Dauern. Night Light verschiebt die Palette (`NightLightState.blend`), nicht als Filter, und weich über Minuten.

## Werkzeuge

| Aufgabe | Werkzeug |
|---|---|
| Shell | Quickshell (QML) |
| Compositor | Hyprland |
| Nachtlicht | hyprsunset |
| Sperrbildschirm | Eigener, in Quickshell (Session-Lock + PAM); hyprlock nur als Notfall-Rückfall |
| Idle | Quickshell `IdleMonitor` (Sperre, Bildschirm aus); dein hypridle bleibt Rückfall |
| Login-Bildschirm | greetd + eigener Greeter in Quickshell |
| Hintergrund | hyprpaper (wird später geprüft) |
| Audio | PipeWire (Quickshell-Modul) |
| Netzwerk / Bluetooth | NetworkManager / BlueZ |
| Akku / Medien | UPower / MPRIS (Quickshell-Module) |
| Power Profile | power-profiles-daemon |
| Clipboard | cliphist + wl-clipboard |
| Caffeine | `IdleInhibitor` (Quickshell, hängt an einem Fenster der Bar); `IdleMonitor` respektiert ihn |
| Drehsensor | iio-sensor-proxy (Verfügbarkeit in Phase 3 prüfen) |
| Benachrichtigungen | Eigener Server in Quickshell |
| Design-Werte | `theme/tokens.json` |
| Installer | Bash-Skript (dnf + COPR) |
| Look-Entwürfe | Statische HTML-Mockups |

## Aktuelle Struktur (Stand Phase 2)

```
theme/tokens.json            Design-Tokens (Quelle der Wahrheit)
config/ai-providers.json     KI-CLIs (erweiterbar)
config/settings.json         Nutzereinstellungen und Standardwerte
config/settings-schema.json  Beschreibung der Settings-App (Kategorien, Einträge)
config/hotkeys.json          Tastenkürzel (Quelle für die Hyprland-Binds)
config/greeter.json          Systemweite Einstellungen des Greeters
config/greetd/config.toml    Vorlage für /etc/greetd/config.toml
shell/theme/Tokens.qml       Singleton, spiegelt tokens.json
shell/models/                Enums, SearchResult, LauncherState, ShellState,
                             TileSpec, WorkspaceInfo, ContextItem,
                             NotificationItem, ChatMessage, AiProvider,
                             AppSettings, SettingsCategory, SettingEntry,
                             SettingsAppState, SettingsSnapshot, HotkeyBinding,
                             LockState, GreeterState, SessionInfo,
                             ClipboardEntry, WallpaperItem
shell/services/              Zustandstypen: NightLight, Audio, Network, Bluetooth,
                             Battery, Display, Media, AiUsage, Calendar,
                             Caffeine, Browser, Focus, PowerProfile, Timer,
                             Weather, SystemMonitor, Capture, DeviceMode
(je Ordner eine qmldir)

Phase 3 ergänzt (nur Signaturen, jeder Körper `throw new Error("not implemented")`):
- Funktionen in fast allen Zustandstypen, z. B. `LauncherState.show/hide/setMode/cycleMode/setQuery/askAi/dock`, `ShellState.openDropdown/openTile/back/closeAll`, `SettingsAppState.save/confirm/revertNow/tick/discardDraft`, `AudioState.setVolume`, `CaffeineState.toggle`, `BrowserState.search`, `Tokens.paletteAt/applyPalette`.
- Neue Singletons nur mit Funktionen: `shell/services/Search, Hotkeys, Compositor, Notifications, Wallpaper, Clipboard, Session, Idle, AiProviders` und `shell/IpcHandlers.qml` (Einstiegspunkte für die Hyprland-Binds).
- `Session` kennt nur lockScreen, logout, restart, shutdown (kein Suspend, kein Hibernate).
- `bin/aptus-settings-watchdog` (start, confirm, restore) und `install.sh` (Schritte als Funktionen), beide ohne Ablauf.

Oberfläche nachgezogen (Phasen 2 bis 4, 74 Dateien, nur Properties, Signale, Platzhalter-Funktionen und TODOs):
```
shell/shell.qml              Einstieg (ShellRoot), noch leer
shell/components/            Surface, Label, IconButton, ToggleSwitch, SliderControl, ListRow
shell/bar/                   Bar, WorkspaceStrip, ContextZone, StatusGroup, BarItem, Clock
shell/dropdowns/             DropdownHost + Audio, Network, Bluetooth, Battery, NightLight, Clock
shell/controlcenter/         ControlCenter, Tile, DetailFrame, tiles/ (17 Kacheln)
shell/launcher/              Launcher, Pill, ModeIcons, ResultList, ResultRow, SpecialResult, EmptyState, AiPanel
shell/notifications/         NotificationPopups, NotificationCard
shell/osd/                   Osd (Lautstärke, Helligkeit, ...)
shell/wallpaper/             WallpaperPicker
shell/touch/                 EdgeStrip (Randwischen)
shell/debug/                 DebugOverlay (Reaktionszeiten)
shell/settings/              SettingsWindow, Sidebar, SearchField, CategoryPage, SettingRow, ChangeBar,
                             ConfirmDialog, editors/ (Provider, Hotkey, TileOrder, Location)
shell/lock/                  LockSurface, PasswordPill, OnScreenKeyboard, ClockBlock
greeter/                     shell.qml, GreeterSurface, UserPicker, SessionPicker, PowerButtons
hypr/                        aptus-look.lua, windowrules.lua, binds.generated.lua, hyprland.lua.snippet
                             (Lua-Gerüste, keine aktiven Einstellungen; kein hypridle, kein hyprland.conf)
bin/aptus                    Start- und IPC-Skript (flock-Datei, `aptus msg …`) für shell-switch
```
Neu in `Enums.qml`: `TextRole`, `OsdKind`, `Edge`. Neu in `Tokens.qml`: `colorFor(severity)`.
```

Noch nicht angelegt: `README.md`, `docs/mockups/`.

## Entscheidungen in Phase 2

- Datenmodelle sind QML-Typen mit reinen Properties, Enums in einem Singleton (`Enums.qml`).
- `Tokens.qml` enthält Konstanten und leere Farb-Properties. Befüllen aus `tokens.json` und Tag/Nacht-Mischen kommt in Phase 7. Doppelte Pflege ist vorläufig.
- Farbe wird aus `Severity` abgeleitet, nicht als Farbwert in den Zuständen gespeichert (erzwingt „Farbe nur funktional").
- `LauncherState.switching` und `previousMode` bilden die Modus-Wechsel-Animation ab.
- Clipboard ist ein Launcher-Modus, Wallpaper Picker ein eigenes Overlay (`Enums.Overlay`).
- Einstellungen (Suchmaschine, Standardmodus, Modus-Tasten, Kalenderquelle) liegen in `config/settings.json`.

## Recherche-Ergebnisse (Phase 3)

- **Open-Meteo:** Kostenlos für nicht-kommerzielle Nutzung, kein API-Schlüssel nötig, Grenzen weit über dem Bedarf (unter 10 000 Aufrufe pro Tag). Daten stehen unter CC-BY 4.0, es braucht also einen Quellenhinweis (in den Settings unter About, oder in der Wetter-Kachel). Quelle: https://open-meteo.com/en/terms
- **Antigravity CLI:** Befehl `agy`, Einzelfrage mit `agy -p "..."`, Ausgabe auf stdout, optional `--output-format json` oder `stream-json`. Quelle: https://computingforgeeks.com/antigravity-cli-cheat-sheet/
- **Mistral Vibe:** Einzelfrage mit `vibe --prompt "..." --max-turns 3 --output text`. Der programmatische Modus läuft standardmäßig mit dem Agenten `auto-approve`, das heißt, er darf Werkzeuge ohne Rückfrage nutzen. Mit `--enabled-tools` lässt sich das einschränken. Quelle: https://docs.mistral.ai/vibe/code/cli/work-with-cli
- **Quickshell auf Fedora:** Offizielles Paket `quickshell` (dnf), alternativ COPR `errornointernet/quickshell` (`quickshell` oder `quickshell-git`). Quelle: https://quickshell.org/docs/v0.3.0/guide/install-setup
- **Greetd-Anbindung:** Quickshell hat ein eigenes Modul `Quickshell.Services.Greetd`, ein Greeter in Quickshell ist damit vorgesehen. Quelle: https://quickshell.org/docs/types/Quickshell.Services.Greetd/Greetd
- **Auto-Drehen:** Unter Hyprland gibt es Hilfsprogramme, die den Lagesensor (`iio-sensor-proxy`) auslesen, zum Beispiel `iio-hyprland`. Ob das auf dem HP Envy x360 zuverlässig läuft, lässt sich nur dort testen (Phase 5).
- Nicht gefunden/offen: passende Bildschirmtastatur für Fedora (Phase 5/7, nur optional).
- Alle Argumente sind laut Dokumentation, aber noch nicht auf deinem Laptop ausprobiert, deshalb bleibt `verified: false`.

## Offene Punkte

- Sicherheit der AI-Kurzfragen: Die CLIs sind Coding-Agenten mit Werkzeugen (Dateien ändern, Befehle ausführen). Für Kurzfragen sollen die Werkzeuge abgeschaltet oder auf „nur lesen" begrenzt werden (z. B. `--enabled-tools` bei Vibe). Je CLI klären und testen (Phase 5).
- Open-Meteo verlangt einen Quellenhinweis (CC-BY): wo zeigen wir ihn?
- Technik des Randwischens: schmale unsichtbare Streifen (16 px) am Rand, die Berührungen annehmen. Nachteil: Fenster darunter bekommen dort keine Berührung. Im Prototyp (Phase 5) prüfen.
- Technik des Drehens: Lagesensor (iio-sensor-proxy) und Umsetzung unter Hyprland, Verfügbarkeit und Verhalten in Phase 3 prüfen. Bildschirmdrehung muss auch Lockscreen und Greeter betreffen.
- Soll der Greeter dasselbe Hintergrundbild wie die Sitzung zeigen oder ein festes?
- Technik des Hilfsprozesses für das Zurücksetzen nach 15 Sekunden (Vorschlag: kleines Skript mit systemd-Timer), wird in Phase 3 festgelegt.
- Soll `tokens.json` zur Laufzeit geladen werden (Live-Änderung) oder beim Bauen in `Tokens.qml` erzeugt werden?
- Repo-Name auf GitHub prüfen (Verfügbarkeit „aptus").
- Ob die Kachel AI usage ohne API-Schlüssel möglich ist, also ob die CLIs Verbrauchsdaten liefern (klären in Phase 3/5).

## Review-Ergebnisse

**Phase 1:** kein Review vorgesehen.

**Phase 2:** Review ohne Sub-Agenten (Agent-Werkzeug wird in dieser Sitzung nur auf ausdrücklichen Wunsch genutzt), Diff selbst gegengeprüft.
- Behoben: Typen waren nicht über `qmldir` registrierbar → `qmldir` je Ordner ergänzt.
- Behoben: `CaffeineState` hatte Dauer-Felder, die der Entscheidung „nur manuell" widersprechen → entfernt.
- Notiert: `SearchResult` hat `mode` und `kind` (leichte Redundanz), in Phase 5 prüfen. `Tokens.qml` und `tokens.json` doppelt gepflegt (siehe oben).
- Nicht prüfbar: ob QML-Enums in einem Singleton mit deiner Quickshell-Version funktionieren; wird in Phase 5 getestet.
- Hinweis: Die Taste Mod + S ist bei dir nun für Settings belegt, Screenshots liegen auf Mod + Shift + S. Beim Anlegen der Hyprland-Config darauf achten, dass die Binds sich nicht überschneiden.

**Phase 3:** Review ohne Sub-Agenten (Agent-Werkzeug nur auf ausdrücklichen Wunsch), Prüfskript über alle QML-Dateien.
- Geprüft per Skript: Jede Funktion hat genau einen Platzhalter-Körper (`not implemented`), kein Funktionsname kollidiert mit einer Property, keine Funktion heißt nach Suspend/Hibernate. Ergebnis: 0 Probleme.
- Regelkonform: Keine neuen Properties oder Typen in bestehenden Dateien, keine Aufrufe, keine Logik.
- Gemeldet, nicht still repariert (gehört in Phase 2, wird von Phase 5 bestätigt): Die neuen Singletons (`Notifications`, `Clipboard`, `Hotkeys`, `AiProviders`, `Compositor`, `Search`, `Wallpaper`) haben keine Listen-Properties für ihre Daten (z. B. die Liste der Benachrichtigungen). `IpcHandlers.qml` braucht für Quickshell einen IPC-Handler-Typ mit Ziel-Namen. Beides ist Struktur und kommt per Phase-5-Lücke nach Phase 2.
- Nicht prüfbar: `qmllint` und Quickshell sind hier nicht installiert, ob die getypten Funktionssignaturen auf deiner Quickshell-/Qt-Version durchgehen, zeigt erst Phase 5.

**Phase 4:** 53 Markierungen `TODO(phase 7): ...` (55 Zeilen, je höchstens zwei Zeilen), 47 in den QML-Dateien und 6 in `install.sh` und `bin/aptus-settings-watchdog`. Sie stehen in den Platzhalter-Körpern und sagen, was später verdrahtet werden muss (z. B. `LauncherState.setMode` → Docken, `SettingsAppState.save` → Snapshot und Watchdog, `Idle.configure` → kein Suspend). Review ohne Sub-Agenten: Ein Vergleich mit dem Stand von Phase 3 ohne die TODO-Zeilen ergab keinen Unterschied, es wurde also kein Code, keine Struktur und keine Signatur verändert.

**Lücken, gemeldet statt still behoben (fehlen aus Phase 2/3, werden von Phase 5 bestätigt):**
- ERLEDIGT (siehe „Oberfläche nachgezogen“ unten): **Die komplette Oberfläche fehlte als Struktur und Signatur.** Bisher gibt es die Daten und die Logik-Hüllen, aber keine Komponenten und keinen Einstieg: `shell.qml`, Leiste mit Workspaces/Kontext-Zone/Status-Gruppe, Dropdowns, Control Center mit Kacheln und Detailansichten, Launcher-Pille mit Modus-Symbolen und angedocktem AI-Panel, Settings-Fenster, Lockscreen-Oberfläche, Greeter-Oberfläche, Wallpaper Picker, Benachrichtigungs-Popups, Bildschirmanzeige für Lautstärke/Helligkeit, Randstreifen für Wischgesten, eingebaute Tastatur. Das ist der Teil, der Aussehen und Gefühl ausmacht.
- ERLEDIGT als Gerüst: **Hyprland-Konfiguration fehlte** (`hypr/`): Rahmen, Abstände, Animationen nach den Tokens, Fensterregeln, Idle-Konfiguration und der Einbindungspunkt der generierten Binds.
- Bereits gemeldet: Listen-Properties in den neuen Singletons (z. B. Liste der Benachrichtigungen) und der IPC-Handler-Typ in `IpcHandlers.qml`.
- Hinweis zu den Tastenkürzeln: Mod + S (Settings) und Mod + Shift + S (Screenshot) müssen beim Erzeugen der Binds sauber getrennt bleiben (als TODO in `Hotkeys.generateHyprlandConfig`).

**Oberfläche nachgezogen (auf Wunsch, Phasen 2 bis 4 für die UI):** Review ohne Sub-Agenten, mit Prüfskript.
- Struktur: 74 Dateien. Komponenten haben nur Properties und Signale. Alle Zustände werden als `var` übergeben (keine Typbindung), damit die Dateien ohne Import-Verdrahtung stehen.
- Signaturen: Insgesamt 228 Funktionen im Projekt, alle mit Platzhalter-Körper. TODOs: 148 Zeilen insgesamt (55 vorher, 93 neu), die Optik-Vorgaben (Dropdown wie Menüleiste, Blur nur auf Control Center und Launcher, 140/260 ms, Farbe nur bei Zustand) stehen als TODO an den jeweiligen Komponenten.
- Geprüft: keine doppelten Namen in einer Datei, keine Logik in den UI-Dateien, keine Funktion mit Suspend/Hibernate, die fünf Hyprland-Dateien haben 0 aktive Zeilen. Das Skript meldete vier Treffer (`text` in BarItem, `title` in ListRow, Tile, SpecialResult); sie sind Fehlalarme, `Item` hat diese Properties nicht.
- Abweichung vom Phasenablauf: Die drei Schichten sind in einem Durchgang entstanden statt mit Halt dazwischen, weil du es so wolltest und sie unabhängig sind. Die Regeln jeder Phase wurden danach geprüft.
- Nicht prüfbar: ob `PanelWindow`, `FloatingWindow` und `ShellRoot` in deiner Quickshell-Version so heißen und ob getypte Signaturen durchgehen (kein `qmllint`, kein Quickshell hier). Phase 5 zeigt das.
- Weiterhin offen: Listen-Properties in den Singletons (`Notifications`, `Clipboard` usw.) und der IPC-Handler-Typ.

## Probe-Ergebnisse (Phase 5)

**Umfang und Grenzen:** Auf einer Wegwerf-Kopie wurden 53 Funktionskörper umgesetzt (Shell-/Launcher-/Settings-Zustände, Hotkey-Konflikte und Hyprland-Generator, Suche inkl. Rechner und Systemaktionen, Farbmischung, Provider-Befehle, Nightlight, Caffeine, Browser). Ausgeführt wurde nur die reine Logik mit Node gegen Attrappen: 28 Prüfungen, alle grün. Nicht ausführbar: `qmllint`/PySide6 (PyPI ist in dieser Sitzung gesperrt, 403), Quickshell, Hyprland. Die Probe sagt deshalb nichts über Quickshell-Typnamen, Rendering, Animation oder Gefühl. Das braucht deinen Laptop.

**Was die Logik bestätigt hat:** Der Ablauf Speichern → 15 s → Rücknahme → Entwurf bleibt → „Verwerfen" funktioniert als reine Zustandsmaschine. Hotkeys in `hotkeys.json` haben keine Konflikte und erzeugen gültige Bind-Zeilen. Die Provider-Befehle halten den Prompt als ein Argument (keine Shell-Injektion). Taschenrechner lehnt Wörter, reine Zahlen und Division durch null ab.

**Lücken, zugeordnet:**

Phase 2 (Struktur/Daten):
- L1: Singletons haben keine Listen-/Datenproperties: `Notifications` (Liste), `Clipboard` (Einträge), `Hotkeys` (bindings), `AiProviders` (Liste), `Compositor` (Workspaces, aktives Fenster), `Search` (Quellen: Apps, Einstellungen). Die Probe musste sie annehmen.
- L2: `AppSettings` braucht `values` als Objekt plus Laden/Speichern der `settings.json` (Datei-Objekt fehlt). Zugriff über Pfad („ai.dockEdge") wird gebraucht, Properties wie `aiDockEdge` sind nur Abkürzungen.
- L3: `SettingsAppState` fehlen `defaults`, `confirmDeadline` und die Uhr (`Timer`, 1 s), die `tick()` aufruft. Der externe Watchdog und der Timer müssen dieselbe Frist kennen.
- L4: `Tokens` kennt `palette` (Roh-Daten aus tokens.json) nicht als Property; Entscheidung offen, ob zur Laufzeit geladen oder generiert wird.
- L5: `Idle` braucht ein Inhibitor-Objekt als Struktur (`inhibitor`), `CaffeineState.setActive` hängt daran.
- L6: Enums brauchen `None`-Werte für `DropdownId` und `TileId` (wird in `back()` und `closeDropdown()` gebraucht); prüfen.

Phase 3 (Recherche):
- L7: Quickshell-Typnamen und -Importe (`PanelWindow`, `FloatingWindow`, `IpcHandler`, `Process`, `FileView`, Session-Lock, Idle-Inhibit, Greetd, Pam) sind nicht gegen die installierte Version belegt.
- L8: IPC-Aufruf: Die Binds rufen `qs ipc call aptus <funktion> <arg>` auf. Ob Funktionen mit Argumenten und das Ziel „aptus" so gehen, ist nicht belegt.
- L9: Hotkey-Aktion „workspace.switch" und Fn-Tasten sind im Generator nur grob umgesetzt; Hyprland-Syntax (`bindel` für Lautstärke/Helligkeit, `bindl` für gesperrte Zustände) fehlt.
- L10: Zen-Browser: Befehl für „neuer Tab im laufenden Zen" und Fokus des Workspace sind unbelegt.

Phase 4 (TODO-Markierungen):
- L11: Querverweise (`Tokens`, `Enums`, `AppSettings`, `Search`, `Idle`, `Compositor`) brauchen Importe in den Dateien; die TODOs nennen sie nicht.
- L12: Zeit-/Prozess-/Datei-Abläufe (Timer-Tick, CLI-Aufruf der KI mit Streaming, cliphist, hyprctl-Events) stehen nur als Text, nicht als eigene TODO je Objekt.
- L13: Bei `Search.runSearch(mode, text)` fehlt die Zuordnung Modus → Quelle; `SearchResult.activate()` ist nicht als Aufgabe markiert.
- L14: Rundungsgrenzen und Fehlerpfade der Funktionen (leere Provider-Liste in `cycleProvider`, `snapshot == null` in `revertNow`) sind in den TODOs nicht genannt. Das gehört in Phase 6 (Invarianten).

**Zustand des Projekts:** Die Wegwerf-Kopie liegt nur im Scratchpad. Das Projekt ist unverändert gleich dem Phase-4-Stand (per Vergleich mit der Sicherung geprüft, 228 Platzhalter-Körper). Die Lücken L1–L14 sind noch nicht in die Phasen 2–4 eingearbeitet.

## Laptop-Befunde (Phase 5, Ergänzung vom 18. Okt.)

Quelle: `tessera-info.txt` vom Laptop (HP ENVY x360 15-ey0xxx).

**Umgebung:** Fedora 44, Kernel 7.2, Hyprland 0.56.2, Quickshell 0.3.2 (COPR lionheartp/Hyprland; zusätzlich ist errornointernet/quickshell eingetragen), Qt 6.11.2 inkl. `qt6-qtdeclarative-devel`. Monitor eDP-1 1920x1080@60, Scale 1. Touch-Gerät und Tablet-Eintrag vorhanden. Open-Meteo ist erreichbar (HTTP 200). Schrift Inter Variable ist installiert (Iosevka Nerd Font auch).

**Neue Fakten, die Pläne ändern:**
- F1: **Die Hyprland-Config ist Lua** (`~/.config/hypr/hyprland.lua`, dazu `noctalia.lua`), es gibt keine `hyprland.conf`. Unsere Scaffolds in `hypr/` und der Bind-Generator sind im `.conf`-Format. Das muss auf Lua umgestellt werden, sobald die Datei gesichtet ist (neue Lücke L15).
- F2: **Es laufen schon andere Shells.** In `~/.config/quickshell/` liegen `noctalia-shell` und `personal-shell`; aktiv ist Noctalia (Bar 22 px, Wallpaper-Layer). Ein eigenes Skript `~/.local/bin/shell-switch` schaltet zwischen Shells um und wird von `hypridle.conf` zum Sperren genutzt (`shell-switch msg session lock`). aptus muss als dritte Config (`~/.config/quickshell/aptus`) danebenstehen und über `shell-switch` oder `qs -c aptus` startbar sein (L16).
- F3: **`/etc/systemd/logind.conf.d/50-hp-sleep.conf` existiert schon.** Unsere Datei `10-aptus-lid.conf` würde von der 50er überstimmt. Inhalt noch unbekannt (L17).
- F4: `hypridle.conf` macht schon genau das Gewünschte (300 s sperren, 600 s Bildschirm aus), nur der Sperrbefehl läuft über `shell-switch`. Unser Generator muss das berücksichtigen oder `shell-switch` ersetzen.
- F5: Quickshell 0.3.2 bringt eingebaute Module mit: `Quickshell.Services` (Greetd, Mpris, Notifications, Pam, Pipewire, Polkit, SystemTray, UPower), `Quickshell.Bluetooth`, `Quickshell.Networking`, `Quickshell.Hyprland`, `Quickshell.Io`, `Quickshell.Wayland`, `Quickshell.WindowManager`. Das schließt L7 zum großen Teil. Für Audio, Mpris, UPower, Bluetooth, Netzwerk und Benachrichtigungen brauchen wir keine eigenen Prozess-Aufrufe.
- F6: `qmllint` ist nicht im PATH, obwohl `qt6-qtdeclarative-devel` installiert ist. Er liegt vermutlich unter `/usr/lib64/qt6/bin/`.
- F7: `hyprpaper` und `cliphist` fehlen. Wallpaper machen wir wie Noctalia selbst als Layer im Shell; `cliphist` muss der Installer nachinstallieren (oder wir bauen den Verlauf selbst mit `wl-paste --watch`).
- F8: `iio-sensor-proxy` läuft, Beschleunigungssensor und Lichtsensor sind da. Auto-Rotate ist machbar (`monitor-sensor`/DBus).
- F9: Zen liegt in `~/.local/lib/zen/zen` (Start über `~/.local/bin/zen`), Fensterklasse `zen`, läuft aktuell auf Workspace 2.
- F10: greetd läuft mit `noctalia-greeter-session`, es gibt mehrere Sicherungen von `config.toml` und eine `edex-electron.toml`. Das PAM-Setup von greetd ist Standard (inkl. gnome-keyring). `fprintd-pam` ist installiert, es gibt aber keinen Sensor.
- F11: CLIs: claude 2.1.302, agy 1.4.0 (`-p`, `--mode accept-edits|auto|plan`, `--effort`, `--sandbox`), vibe 2.26.1 (`-p`, `--max-turns`, `--output text`, `--agent ask|plan|…`, `--enabled-tools`, `--max-price`). Für „nur kurze Fragen ohne Werkzeuge" fehlen noch belegte Flags (offen).

**Zweite Runde (`tessera-info2.txt`) – Ergebnisse:**
- F12: `qmllint` 6.11.2 liegt unter `/usr/lib64/qt6/bin/qmllint` (auch `qmlls`, `qmlformat`). Damit ist ein echter Lint-Lauf auf dem Laptop möglich.
- F13: `50-hp-sleep.conf` setzt `HandleLidSwitch*=ignore` und `IdleAction=ignore`. Das erfüllt „niemals Suspend" schon. Die geplante Drop-in-Datei ist damit überflüssig und wurde gelöscht; der Installer prüft nur (`check_lid_policy`). Deckel-zu → Sperren muss die Shell/Hyprland selbst erledigen (L18).
- F14: **`shell-switch` kennt zwei Shells (`noctalia`, `l-shell`)** und wird in `hyprland.lua` für fast alle Binds genutzt (`shell-switch msg <befehl>`). Es erkennt die laufende Shell über eine flock-Datei `$XDG_RUNTIME_DIR/<name>-<WAYLAND_DISPLAY>.lock`, startet `<bin>` und wartet, bis `<bin> msg log-level-status` antwortet, und stoppt per SIGTERM. aptus braucht deshalb ein Start-Skript `aptus` (hält die flock-Datei, `aptus msg …` → `qs -c aptus ipc call …`) und einen kleinen Patch an `shell-switch` (Liste, Label, `other_shell` für mehr als zwei Shells). Der Patch gehört dem Nutzer, der Installer fragt vorher und legt eine Sicherung an (L16).
- F15: Befehlsvokabular der vorhandenen Binds, das aptus verstehen muss, damit seine Binds weiter funktionieren: `panel-toggle launcher|control-center|notification-center|wallpaper|session|design`, `panel-open launcher [/emo]`, `settings-toggle`, `session lock`, `screenshot-region`, `brightness-up|down`, `volume-up|down|mute`, `mic-mute`, `media prev|next|play-pause`, `keyboard-backlight-up|down|toggle`, `theme-mode-toggle`. `session lock` fällt ohne laufende Shell auf `hyprlock` zurück (gut für uns). aptus-eigene Befehle (`launcher-open web|ai|clipboard …`) kommen dazu.
- F16: Vorhandene Binds kollidieren teilweise mit unseren: Mod+B (Zen direkt starten, wir wollen Web-Modus), Mod+S, Mod+C, Mod+N, Mod+W, Mod+D, Mod+L (Sperren), Mod+Return (alacritty, wir hatten „Terminal" offen; Terminal ist alacritty, `TERMINAL` ghostty), Mod+E (nemo), Mod+Shift+S. Mod+A und Mod+Shift+C sind frei. Entscheidung (18. Okt.): Mod+B bleibt „Zen öffnen", der Web-Modus bekommt Mod+Shift+B (L19 erledigt).
- F17: Hyprland-Lua-API (in der Datei zu sehen): `hl.bind(keys, hl.dsp.exec_cmd(cmd), {locked, repeating, mouse})`, `hl.layer_rule({name, match={namespace}, blur, blur_popups, ignore_alpha, no_anim})`, `hl.window_rule`, `hl.config`, `hl.curve`, `hl.animation`, `hl.gesture`, `hl.on("hyprland.start", fn)`, `hl.exec_cmd`, `hl.env`. L-Shell lädt seinen Look aus `~/.local/state/l-shell/hyprland-design.lua`, nur wenn `choice == l-shell`. Dasselbe Muster eignet sich für aptus (`~/.local/state/aptus/hyprland-look.lua`, 3 Zeilen Patch in `hyprland.lua`). Die Bind für Deckel (Switch-Event) ist in der Lua-API noch nicht belegt (L18).
- F18: `hl.on("hyprland.start")` startet bereits `wl-paste --watch cliphist store &`, aber `cliphist` fehlt im PATH. Der Clipboard-Verlauf geht aktuell ins Leere. Der Installer muss `cliphist` bereitstellen (Fedora-Paket oder Binärdatei), sonst baut aptus den Verlauf selbst.
- F19: Wallpaper kommt aus dem Shell (Layer `noctalia-wallpaper`), kein `hyprpaper`. aptus macht das genauso (eigener Wallpaper-Layer).
- F20: Quickshell-Module in 0.3.2: `Quickshell.Wayland` (IdleInhibitor, IdleNotify, BackgroundEffect, Screencopy, ToplevelManagement, WlrLayerShell, ShortcutsInhibitor), `Quickshell.Hyprland` (Ipc, GlobalShortcuts, FocusGrab, SurfaceExtensions), `Quickshell.Io` (FileView). Session-Lock und Typnamen müssen aus den `.qmltypes` gelesen werden (liegen jetzt im Lint-Paket).
- F21: Zen: `zen --new-tab URL` öffnet einen Tab im laufenden Zen (rc=0, Titel „Example Domain — Zen Browser"). Der Aufruf ist belegt. Fenster hat `class: zen`, die Window-Rule schickt es auf Workspace 2 (damit fokussiert der Workspace-Wechsel automatisch).
- F22: Schnellfrage-Aufrufe (alle ~8 s inkl. Start): `claude -p "…" --model haiku` → „Paris."; `agy -p "…" --mode plan --effort low`; `vibe --agent ask -p "…" --max-turns 2 --output text` (eingebauter Agent „ask", kein Auto-Approve). `vibe --enabled-tools read_file` funktioniert ebenfalls. Alle drei sind mit Zeit ≈ 8 s langsam; die Anzeige braucht Streaming/Lade-Zustand. Für claude fehlt noch die Werkzeug-Beschränkung (`--disallowed-tools`/`--allowed-tools` existieren).
- F23: Der Nutzer hat bereits ein eigenes Projekt „L-Shell" (`~/Code/Projekte/L-Shell`, C++-Binary mit `l-shell-msg`) mit eigenem Design. aptus bleibt davon unabhängig (Projektvorgabe), nur die Schnittstelle (`shell-switch`) wird gemeinsam genutzt.

**Neue Lücken:** L15 Hyprland-Dateien auf Lua umstellen. L16 `aptus`-Startskript und `shell-switch`-Patch. L17 (erledigt durch F13) logind-Drop-in streichen. L18 Deckel-zu → Sperren (Lua-Switch-Bind oder Quickshell-Weg) ungeklärt. L19 Bind-Kollisionen, Mod+B-Entscheidung. L20 Befehlsvokabular (F15) in IPC-Handler und Hotkey-Tabelle aufnehmen. L21 `cliphist` beschaffen.

## Lint- und Typ-Befunde (Phase 5, Laptop, 18. Okt.)

Lauf: `qmllint` 6.11.2 auf Gerüst (`shell/`, `greeter/`) und Probe-Kopie, plus Typbeschreibungen von Quickshell 0.3.2.

**Gerüst:** 0 Fehler. 9 Warnungen, alle `PanelWindow is not creatable`. `FloatingWindow` und `ShellRoot` (Greeter, Settings) warnen nicht, alle Typnamen und `import Quickshell` lösen auf. In der Typdatei ist `PanelWindow` als Interface (`PanelWindowInterface`) markiert; vermutlich Lint-Falschmeldung (wird zur Laufzeit in der Laufzeit-Probe bestätigt, Punkt R1).

**Probe-Kopie:** 33 weitere Warnungen, alle erwartet und deckungsgleich mit den vorab notierten Lücken:
- Querverweise ohne Import (`Enums`, `Search`, `AiProviders`, `AppSettings`, `Tokens`): bestätigt L11.
- `AppSettings` ohne `values`, `set`, `aiDockEdge`, `settingsConfirmTimeoutSec`: bestätigt L2.
- `defaults` in `SettingsAppState`: bestätigt L3. `palette` in `Tokens`: bestätigt L4. `inhibitor` in `Idle`: bestätigt L5.

**Quickshell-Typen (0.3.2), belegt aus den `.qmltypes`:**
- Fenster: `PanelWindow` (anchors, margins, exclusiveZone, exclusionMode, aboveWindows, focusable), `FloatingWindow` (title, minimumSize, maximized, fullscreen …), `PopupWindow`. Namespace über `WlrLayershell` (`WlrLayer`, `WlrKeyboardFocus`).
- IPC: `IpcHandler { target; function …() }` (Funktionen mit Argumenten und Rückgabewert möglich), Aufruf `qs ipc call <target> <funktion> <args>`. Das schließt L8 bis auf die Laufzeitprobe.
- Sperre: `WlSessionLock { locked; surface; unlock() }` mit `WlSessionLockSurface`; Passwort über `PamContext { active, config, configDirectory, user, message, responseRequired, start/abort/respond }`. Greeter: Singleton `Greetd { state, createSession, respond, launch }`.
- Idle: `IdleMonitor { enabled, timeout, isIdle }` (Typ heißt so, nicht „IdleNotify") und `IdleInhibitor { enabled, window }` (braucht ein Fenster; Caffeine/Vollbild).
- Blur: `BackgroundEffect.blurRegion: Region { item: … }` fragt Blur beim Compositor an (ext-background-effect). Alternative bleibt die Hyprland-Layer-Rule. Entscheidung hängt an Laufzeitprobe R2.
- Hyprland: `Hyprland` (`usingLua`, `focusedWorkspace`, `workspaces`, `toplevels`, `dispatch()`, `rawEvent`), `GlobalShortcut`, `HyprlandFocusGrab { active, windows }` (Klick außerhalb schließt Dropdowns).
- Dienste: `Pipewire` (PwNode, PwObjectTracker), `Mpris`, `UPower` + `PowerProfiles { profile }`, `Networking` (WifiDevice, WifiNetwork …), `Bluetooth`, `NotificationServer` (Rechte am D-Bus-Namen: nur eine Shell darf es laufen lassen), `SystemTray`, `Polkit`, `DesktopEntries`, `SystemClock`, `Process`, `FileView`/`JsonAdapter`.
- Konsequenz: Die Services-Zustände können direkt auf Quickshell-Typen aufbauen. Nur Brightness (`brightnessctl`), Nachtlicht (`hyprsunset`), Screenshots (`hyprshot`/`grim`), Kalender, Wetter und KI-CLIs brauchen `Process`.

**Offene Laufzeitpunkte (Laufzeit-Probe auf dem Laptop):** R1 `PanelWindow` wirklich erzeugbar? R2 Blur über `BackgroundEffect` sichtbar? R3 `import qs.models` mit und ohne `qmldir`? R4 `qs ipc --pid … call aptus …` mit Argumenten und Rückgabe? R5 `Hyprland.usingLua` und Dienste (UPower, Pipewire) lesbar? R6 Deckel-Switch in `hyprctl devices`?

## Namensentscheidung und Marke (18. Okt.)

- **Projekt/Repo/Technik: „aptus"** (lateinisch: passend, zweckmäßig). Gilt für Repo, Binary/Startskript `aptus`, Config-Ordner `~/.config/quickshell/aptus`, IPC-Ziel `aptus`, Layer-Namespaces `aptus-*`, Hyprland-Look `~/.local/state/aptus/hyprland-look.lua`. Alle früheren „Tessera"-Stellen im Projekt wurden umbenannt (82 Treffer, Dateien `hypr/aptus-look.conf`, `bin/aptus-settings-watchdog`).
- **Sichtbare Marke in der Shell: „shell."** (klein, mit Punkt, Inter, leicht fett, in der Textfarbe, kein Akzent). Oben links in der Leiste steht nur dieses Wortzeichen; Klick öffnet den Launcher. Gleiches Wortzeichen auf Lockscreen und Greeter. Das Repo-Branding (README, Installer) heißt „aptus".
- Noch nicht geprüft: ob der Name auf GitHub frei ist (die Suche ist hier gesperrt; Nutzer prüft selbst).

## Laufzeit-Probe auf dem Laptop (Phase 5, abgeschlossen, 18. Okt.)

Zweite Quickshell-Instanz mit Mini-Config neben Noctalia:
- R1 **bestätigt:** `PanelWindow` ist erzeugbar (beide Test-Layer in `hyprctl layers`). Die Lint-Warnung `uncreatable-type` ist eine Falschmeldung; sie wird im Projekt per qmllint-Konfiguration stumm geschaltet.
- R2 **bestätigt:** Blur über `BackgroundEffect.blurRegion: Region { item: … }` funktioniert unter Hyprland 0.56.2. Auf dem Screenshot ist der Text hinter Karte A unlesbar (geblurrt), hinter der Kontrollkarte B klar sichtbar. Die Blur-Fläche ist ein Rechteck; die Region kann `radius` (und einzelne Ecken), das setzen wir passend zum Kartenradius. Damit brauchen wir für Control Center und Launcher keine Layer-Regeln, und Bar, Dropdowns und OSD bleiben automatisch ohne Blur.
- R3 **bestätigt:** `import qs.models` funktioniert mit und ohne `qmldir`; ein Singleton braucht `pragma Singleton` und einen `QtObject`-Wurzeltyp. Entscheidung: Ordner-Importe im Stil `import qs.models`, `qs.services`, `qs.theme` (Phase-4-Lücke L11).
- R4 **bestätigt:** `qs ipc --pid <pid> call <target> <funktion> <args>` mit String- und Int-Argumenten und Rückgabewert (`pong`, `echo:hello world`, `abc/42`), `qs ipc show` listet Funktionen. `void` gibt nichts zurück.
- R5 **bestätigt:** UPower (`displayDevice.percentage` = 0,95, also Bruchteil 0..1), `PowerProfiles.profile` (Zahl; 0 = power-saver, passt zu `powerprofilesctl`), Pipewire (`defaultAudioSink.name`), `Hyprland.usingLua = true`, `focusedWorkspace.id = 2` sind alle lesbar.
- R6 **teilweise:** `hyprctl devices` zeigt `Lid Switch` (und „HP WMI hotkeys"). Wie man das Ereignis in der Lua-Config bindet, bleibt offen (L18).
- Hinweis: `console.log` landet nicht in der stdout-Log; Logs liegen unter `/run/user/1000/quickshell/by-id/<id>/log.qslog` (`qs log`). Für Debugging in der Entwicklung nutzen wir IPC-Funktionen oder `qs log`.

## Einarbeitung der Lücken (Phasen 2–4, 18. Okt.)

Geändert nach den Regeln der Phasen 2 (Struktur), 3 (Recherche) und 4 (nur Markierungen, kein Code). Prüfskript: keine Namensdopplung, keine Klammerfehler, kein Suspend im Code, in jeder Funktion nur Platzhalter; 0 Probleme, 235 Platzhalter-Körper.

| Lücke | Stand | Wo |
|---|---|---|
| L1 Daten in Singletons | erledigt | `Notifications.items/unreadCount/doNotDisturb`, `Clipboard.entries/available`, `Hotkeys.bindings/conflicts`, `AiProviders.providers`, `Compositor.workspaceList/activeTitle/clientList` (die drei gleichnamigen Funktionen entfielen), `Search.appEntries/settingEntries` |
| L2 AppSettings | erledigt | `values`, `defaults`, `userConfigPath`, `valueChanged`, `lockAfterMin`, `screenOffAfterMin`, `terminalCommand`, `fileManagerCommand`; Wurzeltyp `Scope`, damit `FileView`/`JsonAdapter` Kinder sein können |
| L3 SettingsAppState | erledigt | `defaults`, Kind-`Timer` (1 s, nur in Phase AwaitingConfirm) ruft `tick()`, Wurzeltyp `Scope` |
| L4 Tokens | erledigt | `palette`, `blend` |
| L5 Idle/Caffeine | erledigt | `Idle` mit `inhibit/caffeine/fullscreenInhibit`, zwei `IdleMonitor`, `Process` für Deckel; `IdleInhibitor` als TODO in `Bar.qml` (braucht ein Fenster); `CaffeineState` ruft `Idle.setCaffeine` |
| L6 Enums `None` | war schon vorhanden | `Overlay`, `DropdownId`, `TileId` haben `None` |
| L7 Quickshell-Typen | erledigt (belegt) | siehe Lint- und Typ-Befunde; `Singleton`/`Scope` als Wurzel für Objekte mit Kindern |
| L8 IPC | erledigt | `IpcHandlers.qml` ist jetzt `Scope { IpcHandler { target: "aptus" } }` mit dem Befehlsvokabular |
| L9 Fn-Tasten/Lua-Syntax | geklärt | Fn-Tasten bleiben in deiner `hyprland.lua` (dort schon mit `locked`/`repeating`); aptus beantwortet nur `volume-up` usw. |
| L10 Zen | erledigt | `zen --new-tab URL` belegt; Workspace-Wechsel durch deine Window-Rule |
| L11 Importe | geprüft, nichts nötig | Skript über alle QML-Dateien: Kein Gerüst verweist im Code auf Typen eines anderen Ordners (Zustände kommen als `var`). Ab Phase 7 gilt der Stil `import qs.models`, `qs.services`, `qs.theme`, `qs.components` (belegt) |
| L12 Prozess-/Datei-Objekte | erledigt | `Process` in `Clipboard`, `Hotkeys`, `Idle`; `FileView`/`JsonAdapter` als TODO an `AppSettings`, `AiProviders`, `Tokens` |
| L13 Suche | erledigt | Quellen je Modus als Kommentar in `Search.qml` |
| L14 Fehlerpfade | verschoben | gehört in Phase 6 (Invarianten) |
| L15 Lua | erledigt | `hypr/*.conf` gelöscht, `aptus-look.lua`, `windowrules.lua`, `binds.generated.lua`, `hyprland.lua.snippet` |
| L16 Start/shell-switch | Gerüst | `bin/aptus` (take_lock, start_shell, send_msg), `install.sh`: `install_launcher`, `patch_shell_switch`; echter Patch in Phase 7 (siehe unten) |
| L17 logind | erledigt | Datei gelöscht, nur Prüfung (`check_lid_policy`) |
| L18 Deckel-zu → Sperren | offen, Plan steht | Primär: Hyprland-Switch-Bind (Lua-API in Phase 7 prüfen). Rückfall: Zustand in `/proc/acpi/button/lid/*/state` einmal pro Sekunde lesen (`Idle.lidProbe`). Quickshell hat keinen Deckel-Typ. |
| L19 Binds | erledigt | Mod+B bleibt „Zen öffnen", Web = Mod+Shift+B |
| L20 Vokabular | erledigt | `IpcHandlers`, `hotkeys.json` (Felder `owner`, `command`) |
| L21 cliphist | Gerüst | `ensure_cliphist` im Installer, `Clipboard.available` |

**Neue Entscheidungen**
- **Hotkey-Eigentum:** Binds, die in deiner `hyprland.lua` schon stehen (Mod+D, S, C, N, W, L, Shift+S, Space, B, Fn-Tasten), bleiben dort. aptus beantwortet nur die `shell-switch`-Befehle und zeigt sie in der Hotkey-Tabelle an. Nur die drei neuen (Mod+Shift+B Web, Mod+A KI, Mod+Shift+C Clipboard) generiert aptus in `binds.generated.lua`, das deine `hyprland.lua` laden darf (Zeilen in `hypr/hyprland.lua.snippet`, Installer fragt vorher und sichert).
- **Idle in aptus:** Quickshell `IdleMonitor` statt eigener hypridle-Datei. Einstellbar in der Settings-App, Caffeine und Vollbild-Fenster werden vom Monitor selbst respektiert. Dein hypridle bleibt unverändert als Rückfall (doppeltes Sperren ist harmlos).
- **Blur:** Über `BackgroundEffect` im Shell selbst, keine Layer-Regeln. Bar, Dropdowns und OSD fragen keinen Blur an.
- **Look-Datei:** `~/.local/state/aptus/hyprland-look.lua`, von deiner `hyprland.lua` nur geladen, wenn `shell-switch` aptus gewählt hat (gleiches Muster wie L-Shell).
- **`shell-switch`-Patch (Phase 7):** `aptus` in `SHELLS`, `label`, `bin_for`; `other_shell` kennt nur zwei Shells, `activate` muss deshalb alle anderen Shells stoppen. Das Skript gehört dir: Der Installer fragt vorher, legt eine Sicherung an und zeigt den Diff.
- **Offene Messung (Phase 7):** Reaktionszeit von `shell-switch msg …` (bash) gegen das 50-ms-Ziel. Falls zu langsam, bekommen die aptus-Binds einen schnellen Direktweg.

**Lint-Lauf auf dem neuen Stand (Laptop):** 0 Fehler, 3 Warnungen, 4 Hinweise (unbenutzte Importe). Behoben: `SettingsAppState` bekam `id: root` (Timer greift qualifiziert zu), `Idle.qml` importiert `Quickshell.Io` (für `Process`), die vier unbenutzten Importe (`Bar`, `AppSettings`, `AiProviders`, `Compositor`) sind entfernt und kommen in Phase 7 zurück, sobald sie gebraucht werden. Greeter war ohne Meldung.

## Phase 6: Invarianten (18. Okt.)

**Vorgehen:** Am Anfang von 112 Funktionen stehen Prüfzeilen der Form `if (<verbotener Zustand>) throw new Error("invariant: Klasse.funktion: Grund")`, davor kommen die TODOs und der Platzhalter `not implemented` unverändert. Insgesamt 174 Prüfungen. Es wurde nichts entfernt (162 TODOs vorher und nachher, 235 Platzhalter vorher und nachher), keine Logik gebaut, kein Refactoring; einzige Zusatzzeile pro betroffener Datei: `import qs.models` in `Tokens`, `Compositor`, `Search`, `Osd` (für `Enums`).

**Was geprüft wird (Auswahl):**
- **Nie Sleep:** `Compositor.dispatch/launch` und `Hotkeys.generateHyprlandLua/writeHyprlandLua` lehnen alles mit `suspend`, `hibernate`, `hybrid-sleep` oder `systemctl sleep` ab. `GreeterState.powerAction` kennt nur Restart und Shutdown.
- **Sperre vor Bildschirm-aus:** `Idle.configure`: ganze Minuten ≥ 0 (0 = nie); Bildschirm-aus > 0 verlangt eine Sperre und eine größere Zeit als die Sperre.
- **Settings sicher übernehmen:** `save` nur mit Änderungen, nie ein zweites Mal während der Bestätigung (würde den Snapshot überschreiben), nie mit vorhandenem Snapshot; `confirm`/`revertNow` nur mit offener Bestätigung und vorhandenem Snapshot (L14); `tick` nur in der Phase und nicht bei 0 Sekunden; `setDraft`/`resetEntry`/`discardDraft`/`resetAll`/`importFrom` nicht während der Bestätigung; unbekannte Einträge abgelehnt; `SettingsSnapshot.create` nicht doppelt, `restore` nicht ohne Snapshot.
- **Zustandsfolge der Oberfläche:** `ShellState` (Dropdown nur aus Geschlossen/Dropdown, Tile nur im Control Center, kein aktives Dropdown außerhalb der Dropdown-Stufe, kein aktives Tile außerhalb der Detail-Stufe); `LauncherState` (Modus gültig, Wechsel/Suche/Auswahl nur bei offenem Launcher, Anbieterwechsel und `askAi` nur im KI-Modus, `askAi` nicht leer, nicht ohne Anbieter, nicht während einer laufenden Anfrage, `dock` nur im KI-Modus).
- **Eingaben von außen (IPC):** Panel-, Modus-, Medien- und Tastaturlicht-Befehle nur aus festen Listen; Bluetooth-Adressen per Muster; Wallpaper-Pfade absolut; Timer 1–86400 s; Lautstärke und Helligkeit 0..1 (keine Überverstärkung); Farbmischung und Nachtlicht-Mischwert 0..1; Nachtlicht-Temperatur im erlaubten Bereich; Seek nicht über das Ende.
- **KI-Anbieter:** Der Befehl ist genau eine ausführbare Datei, nie ein Shell-String; `{prompt}` kommt genau einmal in den Argumenten vor; eingebaute Anbieter lassen sich nicht hinzufügen oder löschen; der letzte aktive Anbieter lässt sich nicht deaktivieren (L14).
- **Clipboard:** Operationen nur mit vorhandenem `cliphist`.

**Prüfung:** Skript über alle Dateien: Klammern stimmen, in jedem Funktionskörper stehen nur Prüfzeilen, Kommentare und der Platzhalter, jede Prüfzeile benutzt nur Properties/Parameter der eigenen Datei. Dazu 60 Node-Fälle (gültige Eingaben laufen bis `not implemented`, verbotene brechen mit `invariant:` ab, z. B. 5/10 min gültig, 0/10 und 10/5 verboten, `systemctl suspend` und `; rm -rf` abgelehnt): 60 grün.

**Review (ohne Sub-Agenten, Diff gegen den Stand vor Phase 6, aus Sicht eines Fremden):**
- Befund 1, berechtigt, behoben: Das Einfügen hatte 88 überflüssige Leerzeilen erzeugt; entfernt (Diff enthält jetzt nur Prüfzeilen und 4 Importe, keine entfernte Zeile).
- Befund 2, berechtigt, behoben: Kommentar in `AudioState` sagte „darf über 1 gehen", die Prüfung verbietet es. Entscheidung: keine Überverstärkung; Kommentar angepasst.
- Befund 3, berechtigt, für Phase 7 notiert: Invarianten auf Eigenschaften (z. B. `docked` nur im KI-Modus, `activeTile` ≠ None nur in der Detail-Stufe, `blend` in 0..1, `confirmSecondsLeft` ≤ Timeout) lassen sich ohne Änderungs-Handler nicht prüfen; ein Handler wäre schon Logik. In Phase 7 als Nachbedingung (Assertion nach der Änderung) umsetzen.
- Befund 4, berechtigt, für Phase 7 notiert: **Einheitenfalle:** Quickshell liefert Akku `percentage` als Bruch 0..1 (Probe: 0,95), `BatteryState.level` und die Schwellen sind Prozent 0..100. Ein vergessenes Umrechnen würde „0,95 %" als kritisch melden. Die Prüfung `0..100` fängt das nicht. In Phase 7 beim Befüllen umrechnen und testen.
- Befund 5, berechtigt, für Phase 7 notiert: Die Regel „Bildschirm-aus nur nach Sperre" muss auch in der Settings-App beim Eintippen gelten (Feldübergreifende Prüfung, sonst scheitert erst `Idle.configure`).
- Abgelehnt: eine Prüfung gegen `lock()` bei bereits gesperrter Sitzung. Sperren muss wiederholbar sein (Leerlauf und Tastendruck lösen es gleichzeitig aus), ein zweiter Aufruf ist kein Fehler.
- Offen für dich: Soll ein Dropdown geöffnet werden dürfen, während der Launcher (Overlay) offen ist? Aktuell nicht geprüft; mein Vorschlag: Der Launcher schließt vorher alle Dropdowns, ein Dropdown öffnet sich nie über dem Launcher.
- IPC: Unbekannte Befehle werfen einen Fehler (im Log sichtbar), die Shell läuft weiter; der Aufrufer bekommt einen Fehlercode. `design` und `session` stehen in der Liste, weil dein `hyprland.lua` sie sendet; `design` ist nur L-Shell und wird in Phase 7 stumm ignoriert.

**Nachtrag zu Phase 6 (18. Okt.):**
- Entscheidung (Nutzer): Der Launcher schließt alle Dropdowns, ein Dropdown öffnet sich nie über dem Launcher oder einem anderen Overlay. Umgesetzt als Prüfung in `ShellState.openDropdown` (Overlay ≠ None → Fehler) und als TODO in `LauncherState.show` (zuerst `ShellState.closeDropdown`). Node-Test: 61 grün.
- Lint-Lauf auf dem Phase-6-Stand: 0 Fehler, 16 Warnungen, alle aus einer Ursache: `qmllint` findet `import qs.models` nicht, weil `qs` erst zur Laufzeit von Quickshell aufgelöst wird (Probe R3 lief dort). Behoben auf der Lint-Seite: `aptus-lint.sh` legt einen temporären Ordner `qs -> shell/` an und übergibt ihn mit `-I`. Zusätzlich heißen die `module`-Zeilen in den `qmldir` jetzt `qs.<ordner>` (z. B. `qs.models`, `qs.controlcenter.tiles`), damit Name und Importpfad übereinstimmen. Gilt für Phase 7 als Lint-Aufruf.

**Lint-Lauf nach der Korrektur (Laptop):** `aptus-lint.sh` mit temporärem `qs`-Ordner: Gerüst und Greeter 0 Warnungen, 0 Fehler. Der Phase-6-Stand ist lint-sauber; dieser Aufruf ist der Standard für Phase 7.

## Phase 7, Abschnitt 1: Basis (18. Okt.)

**Umgesetzt:** `Tokens` (lädt `theme/tokens.json`, Tag/Nacht-Mischung, Schriftwahl Inter), `AppSettings` (Standard + Nutzerdatei `~/.config/aptus/settings.json`, `get`/`set`), `Compositor` (Workspaces, Titel, Fokus, Start), `BatteryState` (UPower, Prozent aus Bruch 0..1 umgerechnet, Schwellen 20/10), IPC-Hardwaretasten (Lautstärke, Mikro, Helligkeit, Medien, Tastaturlicht), Leiste (`Bar`, `WorkspaceStrip`, `ContextZone`, `Clock`, `StatusGroup`, `BarItem`, `Label`), `shell.qml`, `bin/aptus` (Sperre + `msg`), `bin/aptus-patch-shell-switch`, `install.sh` (Abschnitt 1, `--dry-run`/`--yes`), `hypr/aptus-look.lua`, Lua-Block (`hypr/hyprland.lua.snippet`).

**Noch Platzhalter (kommen in späteren Abschnitten):** IPC `panelToggle`, `panelOpen`, `launcherOpen`, `settingsToggle`, `sessionLock` (shell-switch fällt solange auf hyprlock zurück), `screenshotRegion`; Wortmarken-Klick (Launcher); Dropdowns; Kontextzone-Quellen; Statussymbole außer Akku; Tablet-Ausblenden; Nachtlicht-Mischung; `writeUserConfig`.

**In Phase 7 neu aufgetaucht (nicht in Phase 5 gefunden), hier gemeldet:**
- `AppSettings.refreshViews()` (neue Hilfsfunktion, Signatur).
- `BarItem`: `emphasis`, `horizontalPadding`, `default property alias content`; `Label`: `tabularNumbers`; `ContextZone`: `fallbackText`, `priorityThreshold`; `Bar`: `modelData`, `appSettings`, `batteryState`, `windowTitle`, Signal `wordmarkClicked`; `StatusGroup`: Signal `itemClicked`.
- `WorkspaceInfo` bleibt ungenutzt: Der Compositor liefert einfache Objekte.

**Prüfung hier (ohne Quickshell):** Klammerbilanz aller QML-Dateien; Node-Test der Guards 58/61, die 3 Abweichungen sind gewollt (die Funktionen sind jetzt echt implementiert und brauchen Quickshell/Qt); `bin/aptus msg` gegen einen Ersatz-`qs` (Namensabbildung, `session lock`, `keyboard-backlight-up`); Patch gegen den echten `shell-switch`-Text (bash -n ok, zweimal ausführen ändert nichts); Installer in Ersatz-HOME (Links, Block, Patch, zweiter Lauf ohne Änderung).

**Review (selbst, aus Fremdsicht):**
- Befund: `keyboard-backlight-up` hätte eine nicht vorhandene IPC-Funktion gerufen → in `bin/aptus` auf `keyboardBacklight up` abgebildet.
- Befund: `~/.config/aptus` darf nicht als Ganzes verlinkt werden, dort liegt `settings.json` des Nutzers → nur `config`, `theme`, `hypr` einzeln verlinkt.
- Offen, nur auf dem Laptop prüfbar: `qs ipc -p <pfad> call` (Flag-Platzierung), `font.features` für tabellarische Zahlen (bewusst weggelassen), Reaktionszeit von `shell-switch msg` gegen 50 ms, `hl.curve`/`hl.animation`-Syntax der Look-Datei (aus deiner eigenen hyprland.lua übernommen), Kontrast der 12-px-Schrift.

## Phase 7, Abschnitt 2: Launcher (18. Okt.)

**Fehler aus Abschnitt 1 (Laptop, 01:02):** `shell-switch to noctalia` ließ die aptus-Leiste stehen. Ursache: `bin/aptus` nahm die Sperre mit `flock -n 9`; `/proc/locks` nennt dann die PID des `flock`-Hilfsprozesses (schon beendet), nicht die der Shell, also konnte shell-switch sie nicht beenden. Behoben: aptus schreibt `$XDG_RUNTIME_DIR/aptus-$WAYLAND_DISPLAY.pid` (Einzelinstanz-Prüfung über Pid und `comm` qs/quickshell, kein flock, so erben Kindprozesse keine Sperre), und der Patch erweitert `lock_holder` in shell-switch um einen aptus-Zweig. `aptus-patch-shell-switch` ist jetzt inkrementell: ein zweiter Lauf ergänzt nur, was fehlt (auch auf der schon gepatchten Datei).

**Umgesetzt:** `ShellState` (closeDropdown, openOverlay, back, closeAll), `LauncherState` (show, hide, toggle, setMode, cycleMode, setQuery, moveSelection, activateSelected), `SearchResult.activate`, `Search` (Apps über DesktopEntries mit Fuzzy-Ranking, Rechner ohne eval, Web-Zeile), `BrowserState` (detect, search über `zen --new-tab`, danach Workspace des Browsers), `Surface`, Launcher-Fenster (Overlay, Blur über `BackgroundEffect`, Tastatur exklusiv, Monitor mit Fokus), `Pill`, `ModeIcons` (schwebende Kapsel, gleitender Kreis), `ModeGlyph` (gezeichnete Symbole), `ResultList` (gleitende Auswahl), `ResultRow`, `SpecialResult` (Rechnerergebnis groß), `EmptyState` (eine Hinweiszeile), IPC `panelToggle|panelOpen launcher`, `launcherOpen`, Klick auf „shell.“. Tasten: Esc, Pfeile / Strg+N,P,J,K, Tab / Shift+Tab, Enter, Strg+1..5 (aus den Einstellungen).

**Noch Platzhalter:** Modi Settings, AI, Clipboard (zeigen eine Hinweiszeile), AI-Dock, zuletzt benutzte Apps und Fenster-Karten, Fenstersuche, Systemaktionen, Web-Vorschläge.

**Neu aufgetaucht (nicht in Phase 5 gefunden):** `SearchResult.run` (Funktion mit der Aktion), `LauncherState.shellState`, `Search.browser`, `Search.maxResults`, `Search.makeResult/discardBatch/calc` (Hilfsfunktionen), `ModeGlyph` (neue Komponente), `Pill.input/previousMode/navigationKey`, `EmptyState.hint`, `ResultList.selectionRequested`, `Launcher.appSettings/refresh/pickScreen`, `IpcHandlers.launcherState/shellState`.

**Prüfung hier:** Node-Test von Rechner (Klammern, Potenz, Modulo, Fehlerfälle), Fuzzy-Ranking, Launcher- und ShellState-Logik (39 Fälle grün), Klammerbilanz; pid-Datei-Suche und Zweitinstanz-Sperre mit einem Ersatz-`qs`; Patch frisch und als Upgrade der alten Patch-Version (gleiches Ergebnis).

**Offen, nur auf dem Laptop prüfbar:** Blur hinter dem Launcher (Blur-Region ist fest, der Blur erscheint mit dem Fenster und blendet nicht weich aus), Canvas-Symbole (`roundedRect`, Skalierung), Tastaturfokus (Exklusiv), Zen-Tab im laufenden Browser, Reaktionszeit Hotkey → Launcher.

**Laptop-Test Abschnitt 2, erster Lauf (01:08):** Leiste da, Patch lief, aber `aptus msg panel-toggle launcher` öffnete nichts. Ursache: `~/.local/bin/aptus` und `~/.config/quickshell/aptus` zeigten noch auf den Ordner `aptus-phase7a` (der Installer von Abschnitt 1 hatte dorthin verlinkt), die laufende Shell war also der alte Stand, dessen `panelToggle` noch „not implemented“ warf (ein IPC-Fehler erscheint nur im Log, nicht im Terminal). Lehre: ein fester Projektordner statt je Abschnitt ein neuer; `install.sh` erneut ausführen verlinkt um (alte Links landen als `.before-aptus`). Lint 2 Warnungen: `blurRegion` (qmllint kennt den Wayland-Typ nicht, zur Laufzeit geprüft, jetzt mit `qmllint disable` gekennzeichnet) und `scrim` (jetzt über `win.blurTarget`), dazu 4 ungenutzte Importe entfernt.

**Laptop-Test Abschnitt 2, zweiter Lauf (01:21): alles aus TEST-ABSCHNITT-2.md funktioniert.** Eine Anmerkung des Nutzers: der Blur dürfte etwas schwächer sein. Entscheidung: vorerst lassen, als Politur für später notiert (die Stärke kommt aus `decoration.blur` in `hypr/aptus-look.lua`, z. B. `passes` 3 → 2 oder `size` 8 → 6; der Schleier im Launcher ist `Tokens.overlayDim`).

## Phase 7, Abschnitt 3a: Dropdowns (18. Okt.)

**Aufteilung:** Abschnitt 3 ist in 3a (Dropdowns) und 3b (Kontrollzentrum, Kacheln, Detailansichten, Netzwerk, Bluetooth) geteilt, damit zwischendurch getestet werden kann.

**Umgesetzt:** `ShellState.openDropdown`; echte Zustände: `AudioState` (PipeWire: Lautstärke, Stumm, Ausgabe-/Eingabegeräte, Mikrofon), `DisplayState` (brightnessctl, Untergrenze 1 %), `NightLightState` (hyprsunset starten/setzen, Palette-Mischung über `Tokens.applyPalette` mit 4 s weichem Übergang, Zeitplan 20:00 bis 07:00), `PowerProfileState` (power-profiles-daemon über UPower), `CalendarState` (Monatsraster, Montag zuerst, noch ohne Termine); Komponenten `SliderControl`, `ToggleSwitch`, `ListRow`, `StatusGlyph` (gezeichnete Symbole: Lautstärke mit Wellen und durchgestrichen, Mikro, Mond); `DropdownHost` (Fenster unter der Leiste, schließt bei Klick daneben, rechtsbündig am Symbol, 140 ms) mit `AudioDropdown`, `BatteryDropdown` (Prozent, Restzeit, Energieprofil), `ClockDropdown` (Monat, Blättern, Heute, Auswahl) und `NightLightDropdown` (Schalter, Temperatur, Zeitplan, Helligkeit); Leiste: Lautstärke- und Mond-Symbol, Klick auf Akku und Uhr.

**Noch Platzhalter:** Netzwerk- und Bluetooth-Dropdown (3b), Verweis „More“ ins Kontrollzentrum, Esc nur nach einem Klick ins Dropdown (Tastaturfokus „bei Bedarf“), Termine im Kalender (iCal später), echter Sonnenauf-/untergang, OSD bei Funktionstasten.

**Neu aufgetaucht (nicht in Phase 5 gefunden):** `StatusGlyph` (neue Komponente); `DropdownHost.openAt` bekam einen dritten Parameter (Bildschirm) und die Dienste als Eigenschaften; `Bar.dropdownRequested/audioState/nightLightState`; `AudioState.devices`, `describe`, `listNodes`, `nodeByName`; `CalendarState.monthGrid`; AudioState, DisplayState, NightLightState, CalendarState sind jetzt `Scope` statt `QtObject` (sie haben Kindobjekte).

**Prüfung hier:** Node-Test (18 Fälle: Dropdown-Zustand, Nachtlicht-Mischung, Monatsraster für Oktober 2026, Terminfilter, Wertgrenzen), Klammerbilanz.

**Offen, nur auf dem Laptop prüfbar:** PwNodeType-Filter und `PwObjectTracker` auf allen Knoten (Geräteliste), `hyprctl hyprsunset`, ob `Tokens.applyPalette` im Zeitlupen-Übergang ruckelfrei ist, gezeichnete Symbole (Mond!), Lage und Schließen der Dropdowns.

**Laptop-Test Abschnitt 3a (01:36): alles aus TEST-ABSCHNITT-3A.md funktioniert.** Zwei Befunde: (1) Alle Energieprofil-Knöpfe hießen „Saver“. Die Knöpfe nutzen jetzt Einträge `{ id, name }` (wie die bewährten Geräte-Listen) statt Zahl-Index in ein Namens-Array. Die eigentliche Ursache des Index-Fehlers blieb ungeklärt; die neue Form umgeht ihn. (2) Der Akku zeigte „Plugged in“, obwohl nur das Handy am Laptop hing: `UPower.onBattery` ist dann falsch. `BatteryState.pluggedIn` richtet sich jetzt nach dem Zustand der Batterie (nicht „Discharging“), dazu neu `discharging` und `fullyCharged`; Texte: „Fully charged“, „On battery“, „Charging“, „Plugged in“. Lint 5 Warnungen behoben (`margins { top }`, `(loader.item as Item)`, `qmllint disable unqualified` für `blurTarget`, ungenutzter Import).

## Phase 7, Abschnitt 3b: Kontrollzentrum (18. Okt.)

**Umgesetzt:** `ShellState` (openControlCenter, openTile, back mit den Stufen Detail → Kontrollzentrum → zu), `Idle.setCaffeine/setFullscreenInhibit` (inhibit per Bindung), `CaffeineState`; echte Zustände `NetworkState` (Quickshell.Networking: WLAN an/aus, Netzliste, Scan nur bei offener Liste, Verbinden mit Passwort, Trennen, Vergessen), `BluetoothState` (BlueZ: an/aus, Suche, Verbinden, Koppeln, Akkustand), `MediaState` (MPRIS: Titel, Cover, Position jede Sekunde, Suchen); Oberfläche: `Tile` (Rahmen mit Hover-Tönung), `DetailFrame` (wächst in 260 ms aus dem Rechteck der Kachel, Zurück-Knopf für Touch), `ControlCenter` (Vollbild-Overlay, Blur, Schleier, 4x4-Raster, vorgeladen, Esc als Shortcut eine Stufe zurück, Klick daneben schließt), Kacheln Sound, Display, Network, Bluetooth, Power, Caffeine (nur Umschalter), Media, Calendar; Detailansichten teils aus den Dropdown-Inhalten (Audio, Display, Power, Kalender); `StatusGlyph` um play, pause, next, prev, cup, back, sliders erweitert; Leiste: Regler-Symbol ganz rechts öffnet das Kontrollzentrum; IPC `panel-toggle|panel-open control-center` (schließt vorher den Launcher).

**Noch Platzhalter (Abschnitt 4):** Kacheln Notifications, AI usage, Focus, Timer, Weather, System monitor, Capture, VPN, Hotspot (`NetworkState.setVpn/setHotspot`), `panel-toggle notification-center`.

**Neu aufgetaucht (nicht in Phase 5 gefunden):** `NetworkState.signal` umbenannt in `signalStrength` (`signal` ist in QML ein Schlüsselwort), `NetworkState.stopScan/wifiDevice/wifiList/byName`, `BluetoothState.connectedCount/liveDevices/byAddress`, `BluetoothState.devices` mit `batteryPercent`, `MediaState.player`, `ControlCenter.activate/titleOf/componentFor` und die Eigenschaften der Dienste, `DetailFrame.targetRect/title/contentComponent`, `PowerProfileTile.batteryState`, `IpcHandlers.openControlCenter`, `Bar.controlCenterRequested`. `TileSpec` bleibt ungenutzt (Layout als einfache Objekte).

**Prüfung hier:** Node-Test der Stufen (16 Fälle: CC öffnen, Kachel, zurück, Dropdown/Launcher/CC schließen sich gegenseitig, Koffein, Bluetooth-Adressen, Medien-Grenzen), die älteren Tests weiter grün, Klammerbilanz.

**Offen, nur auf dem Laptop prüfbar:** Quickshell.Networking (Netzliste, Verbinden mit Passwort), Bluetooth (Suche, Koppeln, `battery` als Bruch oder Prozent), MPRIS-Position, Aufziehen der Detailansicht (Ruckeln?), Blur im Kontrollzentrum, Lage und Größe des Rasters auf 1920x1080, Esc-Shortcut, ob das Regler-Symbol rechts gut aussieht.

## Abschnitt 3b, Nachbesserung nach Laptop-Test (19. Okt.)

Rückmeldung: Kontrollzentrum gut; Sound-Kachel zeigte „Muted“ über dem Regler; Detailansichten füllten den Platz nicht. **Umgesetzt:** Sound-Kachel zeigt Stumm nur noch über abgedunkelte Zahl, durchgestrichenes Lautsprecher-Symbol und abgeblendeten Regler (kein Text). Detailansichten für den Platz gebaut (Fläche ca. 732x448): Sound = Ausgabe links / Eingabe rechts mit Regler, Stumm-Schalter, Geräteliste; Display = Helligkeit links / Nachtlicht rechts; Power = Akku mit Balken links / drei große Profilkarten rechts; Kalender = großer Monat (`components/MonthView`, auch im Dropdown) / Tag mit Terminen. Lint-Funde (Imports, Tile.radius, Pragmas, margins/UntypedObjectModel) bereinigt. Nicht hier prüfbar (kein qmllint, keine Oberfläche) – Lint und Optik auf dem Laptop.

## Phase 7, Abschnitt 4a: übrige Kacheln (19. Okt.)

**Entscheidung (Variante 2):** Raster jetzt 6 Spalten x 5 Zeilen (Brett bis 1080 px breit, 668 px hoch), kleine 1x1-Schalter statt zweiter Seite. Detailansicht bleibt eine feste Fläche (800x540) in der Mitte, die aus der Kachel wächst; die abgenommenen Detail-Layouts bleiben so unverändert. Layout: Zeile 0 Sound, Display, Network, Bluetooth; Zeile 1 Power, Caffeine, Focus, VPN, Hotspot, Capture; Zeile 2 Timer, Weather, Notifications; Zeilen 3-4 Media, Calendar, AI usage, System.

**Umgesetzt:** `FocusState` (Tipp schaltet um), `TimerState` (Timer + Pomodoro, Endzeit als Uhrzeit, `notify-send` am Ende), `SystemMonitorState` (/proc, hwmon, df; läuft nur bei offenem Kontrollzentrum), `WeatherState` (Open-Meteo per XMLHttpRequest, alle 30 min, Ort aus den Einstellungen, Quellenhinweis CC BY), `CaptureState` (grim, slurp, wl-copy, wf-recorder; Kontrollzentrum schließt sich vorher; fehlende Programme werden angezeigt), `NetworkState` VPN/Hotspot über nmcli, `AiUsageState` (ehrlich: kein Anbieter verbunden). Kacheln Focus, VPN, Hotspot, Capture, Timer, Weather, System monitor, AI usage, Notifications (Anzeige „All clear“). Neue Bausteine `ActionButton`, `MeterBar`, 12 neue Symbole in `StatusGlyph`. `PowerProfileState` schaltet jetzt zusätzlich über `powerprofilesctl`, wenn die Eigenschaft nicht greift (Profilkarten waren nicht anwählbar).

**Offen (Abschnitt 4b):** Benachrichtigungsserver, Verlauf, Popups, OSD, `panel-toggle notification-center`, Notifications-Kachel mit Liste, Zähler für Focus; Netzwerk-/Bluetooth-Dropdowns; echter Sonnenauf-/untergang für das Nachtlicht.

**Nicht hier prüfbar:** alles Optische, Open-Meteo-Abruf, nmcli-Ausgaben (VPN/Hotspot), grim/wf-recorder, Rechenwerte des Systemmonitors, Pomodoro-Wechsel.

**Nachbesserung 4a (19. Okt., Laptop-Test):** Ursache der Power-Profil-Fehler gefunden: in `Enums` hieß ein Wert von `TileId` ebenfalls `PowerProfile`, dadurch war `Enums.PowerProfile.Saver` überall `undefined` (alle Karten „Saver“, Klick wirkungslos, Log „Unable to assign [undefined] to int“). Enum umbenannt in `Enums.PowerMode`, UPower-Import in `PowerProfileState` mit Alias `UP`. Capture: Fehlerausgabe, „Open folder/Open last“, letzter Pfad in der Ansicht, IPC `screenshot-region|screen|window` und `record-toggle` für die Hotkeys; Region-Auswahl bleibt auf dem Laptop zu prüfen.

**Farbkonzept Kontrollzentrum (19. Okt., auf Wunsch von Lenno, erweitert die Regel „Farbe nur als Signal“):** Farbe steht nur auf kleinen Elementen (Symbol, Statuswort, Punkt, Balken), nie auf Kachelflächen, höchstens eine Farbe je Kachel, und immer zusätzlich Text oder Form (auch ohne Farbsehen lesbar). Grün (ok) = aktiv/verbunden/spart: WLAN und Bluetooth verbunden, Nachtlicht an, Caffeine/Focus/VPN/Hotspot an, Timer läuft, Profil „Saver“, Akku lädt. Amber (warn) = kostet etwas oder Achtung: Profil „Performance“, Akku niedrig, Temperatur/RAM/Disk hoch. Rot (critical) = stumm, Aufnahme läuft, Akku kritisch, Speicher fast voll. Neutral (Tinte) = Normalzustand; aus = blass. Umgesetzt in Sound, Network, Bluetooth, Display, Power, Timer, Capture, System.

**Nachbesserung 4a, zweiter Teil:** Systemmonitor-Detail deutlich reicher (Verlaufsgraph CPU 90 s, Frequenz, Temperatur, Kerne, Last, Laufzeit, GPU falls Sensor da, RAM mit Swap, bis zu 2 Laufwerke, Netz mit Verlauf, fünf aktivste Programme; `components/Sparkline`). Capture: Kontrollzentrum wird vor der Aufnahme sofort ausgeblendet (Verzögerung 700 ms; erster Screenshot war weiß), „Open folder“ schließt das Kontrollzentrum.

**Nachbesserung 4a, dritter Teil:** Aufnahme: roter pulsierender Punkt mit Zeit in der Leiste (Klick stoppt), Capture-Kachel zeigt „Stop 0:12“ und stoppt per Tipp, Stopp robuster (Signal an den Prozess, `pkill -INT`, nach 4 s `-TERM`), Fehlerausgabe von wf-recorder sichtbar. Weißer Screenshot: `grim` allein funktioniert (Lenno), also lag es am noch sichtbaren Kontrollzentrum.

## Phase 7, Abschnitt 4b: Benachrichtigungen und OSD (19. Okt., jetzt direkt auf dem Laptop gebaut und getestet)

**Capture-Fehler behoben:** `wf-recorder` fragte bei zwei Monitoren interaktiv nach dem Ausgang (jetzt `-o <fokussierter Monitor>`); `slurp` las stdin bis EOF und blockierte unter Quickshell (jetzt `</dev/null`). Beides auf dem Laptop reproduziert und per IPC geprüft. IPC neu: `record-screen-toggle`.

**Umgesetzt:** `Notifications` (NotificationServer, Verlauf 100, Popups max. 4, Timeout aus Einstellungen oder vom Sender, kritisch bleibt stehen, Hover pausiert, Focus hält Popups zurück und zählt, kritisch kommt durch), `NotificationCard` (App-Icon oder Buchstabe, Zeit, Zusammenfassung, Text mit Markup, Aktionsknöpfe, X), `NotificationPopups` (oben rechts/links/mitte unter der Leiste, Monitor mit Fokus), Notifications-Kachel (Zähler, Verlauf, Clear all, liest beim Öffnen alles), `panel-toggle|panel-open notification-center` (Kontrollzentrum direkt im Detail), OSD (`Osd`: Lautstärke, Helligkeit, Mikro, Koffein/Rotation per Text; erscheint sofort, 140 ms Ausblenden, nimmt keine Eingabe), IPC-Tasten `volume-up|down|mute`, `mic-mute`, `brightness-up|down` laufen jetzt über die Shell mit OSD. Aufnahme-Meldungen („Screenshot saved“) laufen über unseren Server.

**Noch offen:** Netzwerk-/Bluetooth-Dropdowns, Sperrbildschirm-Datenschutz für Benachrichtigungen (Lockscreen-Abschnitt), Koffein/Rotation-OSD verdrahten, echter Sonnenauf-/untergang, Kalenderquelle, Aktionen „Open“ nur wenn der Sender sie auswertet.

**Nachträge 4b (19. Okt.):** Netzwerk- und Bluetooth-Dropdowns (Schalter, Liste, „More“ öffnet die Kachel im Kontrollzentrum über `IpcHandlers.openTile`), Leisten-Symbole WLAN/Bluetooth (Glyphen `wifi`, `bluetooth`), Caffeine und Focus erscheinen grün in der Leiste solange an, Stumm-Symbol rot, Caffeine-OSD, echter Sonnenauf-/untergang für das Nachtlicht (Sonnengleichung, Ort aus Wetter-Einstellung, Berlin 19. Okt. 07:38/18:04 geprüft), iCal-Kalender (`calendar.icsUrl`, nur lesen, einfache Wiederholungen, alle 15 min, TZID als Ortszeit), Fenstertitel in der Leistenmitte exakt zentriert. **Weiter offen:** Sperrbildschirm-Datenschutz (kommt mit dem Sperrbildschirm), Klick-Test der Dropdowns (ydotool klickt hier nicht).

**Kalender (19. Okt.):** mehrere private iCal-Quellen zusammengeführt (`calendar.sources` in `~/.config/aptus/settings.json`, je `name`, `url`, optional `color`; Standardfarben aus einer Palette), farbige Punkte im Monat (max. 3 je Tag), farbige Terminzeilen (`EventRow`), mehrtägige Termine, `panel-open control-center <kachel>`. Monatszelle: Kreis (heute gefüllt, Auswahl Ring) nur um die Zahl, Punkte darunter, nichts überlappt.

## Phase 7, Abschnitt 5: KI-Dock und Clipboard (19. Okt., direkt auf dem Laptop gebaut und getestet)

- **Clipboard-Modus** (Mod + Shift + C, Strg + 5): `Clipboard` liest `cliphist list`, Enter kopiert den Eintrag zurück (`cliphist decode | wl-copy`), Shift + Entf löscht ihn, die Suche filtert den Text, leer zeigt die neuesten. Bilder erscheinen als Zeile „Image, …“ (noch ohne Vorschaubild). Ohne `cliphist` zeigt der Modus einen Hinweis. `cliphist` 0.7.0 lag nicht im PATH; als Binärdatei nach `~/.local/bin` gelegt (Installer muss das später tun, F18/L21). `pin` und `ClipboardEntry` entfielen (cliphist kennt kein Anheften).
- **KI-Modus** (Mod + A, Strg + 4): eigenes Fenster `AiPanel` am rechten Rand (Breite `ai.dockWidth`, Seite `ai.dockEdge` rechts/links/unten), ohne Blur, der Rest des Bildschirms bleibt sichtbar. Das Launcher-Fenster blendet sich im KI-Modus aus. Kopf mit Anbieter, Alt + Pfeil wechselt, „Clear“, „Close“; Esc schließt, Tab und Strg + 1..5 wechseln den Modus (zurück in die Mitte mit Blur).
- **Anfragen:** `AiProviders` lädt `config/ai-providers.json` und `~/.config/aptus/ai-providers.json`, startet die CLI einmalig (`quickArgs`, Arbeitsordner `/tmp`), Antwort kommt zeilenweise. Die CLIs haben kein Gedächtnis, deshalb gehen frühere Runden im Prompt mit. Verlauf ist beim Schließen weg. Geprüft: `claude -p` (mit `--tools ""`), `agy -p`, `vibe --prompt` antworten; im Panel getestet mit Claude („22 one word“ → „SSH“).
- **Offen:** keine Werkzeug-Sperre für `agy` und `vibe` (nur der Prompt sagt „ohne Werkzeuge“); Anbieter hinzufügen/deaktivieren (Settings-App); Alt+Pfeil und Dock links/unten ungetestet; Eingabe per Hotkey-Fokus (`Exclusive`) bedeutet, dass Klicks in andere Fenster den Tastaturfokus nicht mitnehmen; Web-Modus unverändert (öffnet Zen, aus Abschnitt 2); Tile „AI usage“ hat noch keine echten Daten.

**Nachträge 5 (19. Okt., Abend):** Mod + A, Mod + Shift + B und Mod + Shift + C fehlten in der Lua-Bind-Datei (`hypr/binds.generated.lua` war leer); jetzt echte Binds auf `shell-switch msg launcher-open <modus>`. KI-Panel gleitet aus dem Rand herein, Kopf/Verlauf und Eingabe setzen gestaffelt ein (70/130 ms Versatz), Schließen ist schneller (140 ms). Hover: Kacheln heben sich 2 px, Rand dunkelt, Schatten vertieft, graue Tönung; Leistenelemente bekommen eine deutlichere graue Pille (Tinte 9 % / gedrückt 14 %), die beim Einblenden leicht wächst. Hover per Screenshot nur mit erzwungenem Zustand geprüft (synthetische Mausbewegung löst im Layer keinen Hover aus).

## Phase 7, Abschnitt 6: Settings-App (19. Okt., direkt auf dem Laptop gebaut und getestet)

- **Fenster** (`SettingsWindow`, eigenes Fenster `aptus settings`, Mod + S über `settings-toggle`): Seitenleiste mit 10 Kategorien, Suche oben, Seite rechts, Änderungsleiste unten, „Show advanced“. Die Einträge kommen aus `config/settings-schema.json`. Editoren: Schalter, Auswahl (Pillen), Schieberegler, Zahl (− / +), Text (maskiert bei `secret`), Aktion. Geänderte Werte tragen „Changed“, „Reset“ setzt einen Wert auf den Standard. Hyprland-Regel in `hypr/windowrules.lua`: schwebend, 980 × 680, zentriert.
- **Speichern mit Rückfrage:** Save → der Watchdog sichert `~/.config/aptus/settings.json` (erst danach werden die Werte angewendet, sonst Wettlauf), 15 s `ConfirmDialog` (eigenes Overlay, große Knöpfe Keep / Revert now). Ohne Antwort stellt die Shell die alten Werte wieder her, der Entwurf bleibt im Formular (Phase „Reverted“). `bin/aptus-settings-watchdog` läuft als eigener Prozess (`setsid`) und stellt die Datei auch bei abgestürzter oder hängender Shell nach Timeout + 3 s wieder her. Geprüft: Anwenden (Sekunden in der Leiste), automatisches Zurücksetzen, Watchdog nach `kill -9` der Shell (Datei danach identisch zum Vorher-Stand).
- **Schreiben:** `AppSettings.writeUserConfig` schreibt nur Abweichungen von den Standardwerten, behält unbekannte Schlüssel der Benutzerdatei und den Dateimodus (600, wegen der privaten Kalenderadressen). Export schreibt nach `~/aptus-settings.json` ohne Kalenderadressen; Import liest in den Entwurf; „Reset all“ setzt alle Werte als Entwurf auf den Standard.
- **Launcher-Modus Settings** (Strg + 3): leer zeigt die Kategorien, Text sucht Einträge (Titel, Beschreibung, Stichwörter); Enter öffnet die App beim Eintrag und hebt ihn kurz hervor.
- **Entfallen:** `SettingEntry`, `SettingsSnapshot` (einfache Objekte statt Modelle).
- **Noch nicht:** Editoren für Listen, Anbieter, Kacheln, Kürzel, Ort (zeigen „Edit this in ~/.config/aptus/settings.json for now“), Wallpaper-Aktion, Kürzel-Konflikte; nicht jede Einstellung wirkt schon in der Oberfläche (die Leiste und das KI-Dock lesen live, andere erst bei späteren Abschnitten). Die Regel in `windowrules.lua` lädt hyprland.lua nur bei gewählter Shell „aptus“.

## Phase 7, Abschnitt 7a: Sperrbildschirm und Idle-Regeln (19. Okt., auf dem Laptop gebaut und getestet)

- **Sperrbildschirm** (`LockScreen`, `LockSurface`, `LockState`): Wayland-Session-Lock (`WlSessionLock`), Anmeldung über PAM (`PamContext`, Konfiguration `login`, aktueller Benutzer). Warmer Verlauf, große Uhr (132 px, Light), Passwortpille wie im Launcher, bei falschem Passwort Wackeln, roter Rand und „Wrong password“. Das Passwort liegt nur kurz in `LockState.password` und wird sofort nach dem Senden geleert. Benachrichtigungen zeigen nur die Anzahl (Text nur mit `lock.showNotificationContent`). Auslöser: `aptus msg session lock` (dein Mod + L), Leerlauf, Deckel zu.
- **Eingebaute Tastatur** (`OnScreenKeyboard`, deutsches Layout mit Ziffern-/Zeichenebene): Knopf „Keyboard“, im Modus `auto` automatisch nach einer Berührung, `always` / `never` über `touch.lockKeyboard`. Uhr und Pille rücken nach oben.
- **Idle** (`Idle`): Sperre nach `system.lockAfterMin` (5), Bildschirm aus nach `system.screenOffAfterMin` (10), nur zusammen mit einer früheren Sperre, 0 = nie; Aus über `hyprctl dispatch hl.dsp.dpms`, zurück bei Aktivität. Caffeine und Vollbildfenster (`system.keepAwakeWhenFullscreen`, Hyprland-Ereignis `fullscreen`) halten beides an. Deckel zu sperrt (ACPI-Status alle 2 s gelesen, nur wenn `system.lidClose` = lock). Nie Suspend/Hibernate.
- **Session:** `logout` (`hl.dsp.exit()`), `restart`, `shutdown` (systemctl). Noch kein Power-Menü (`panel-toggle session`).
- **Geprüft:** Sperren per IPC, falsches Passwort (PAM meldet „Failed to authenticate“, Oberfläche zeigt Fehler), Tastatur-Ansicht, Entsperren. **Nicht geprüft:** richtiges Passwort (von dir einmal bestätigt, siehe unten), Berührung, Leerlauf-Auslösung, Deckel, Bildschirm-Aus nach Sperre.
- **Notausstieg:** Stirbt die Shell bei gesperrtem Bildschirm, bleibt er gesperrt. Mit Strg + Alt + F3 auf die Konsole, anmelden, `pkill hyprlock; qs -p ~/.config/quickshell/aptus` oder die Shell neu starten (ein Neustart der Shell setzt die Sperre zurück, sie startet nicht gesperrt).
- **Offen für 7b:** Greeter (greetd), Touch (Randstreifen, Tablet-Modus, Drehen), Installer-Schritte (`ensure_cliphist`, Watchdog-Link, Greeter, Lid-Prüfung), Power-Menü, Hintergrundbild auf dem Sperrbildschirm (kommt mit dem Wallpaper-Picker).

### Abschnitt 7b-1 (Power-Menü, Touch, Tablet)
- **Power-Menü** (`shell/session/PowerMenu.qml`): Lock, Log out, Restart, Shut down; Restart/Shut down brauchen einen zweiten Tipp (roter Rand, „Tap again“, 4 s). Aufruf: Mod+X (`panel-toggle session`), Knopf oben rechts über dem Kontrollzentrum, Esc oder Klick daneben schließt.
- **Tablet-Modus** (`DeviceModeState`): liest den Tablet-Schalter (SW_TABLET_MODE) per kleinem Python-Loop direkt vom Eingabegerät (Nutzer ist in Gruppe `input`); Lagesensor über `monitor-sensor --accel`. Auf dem Laptop meldet der Schalter im Laptop-Betrieb 0.
- **Drehen:** nur im Tablet-Modus mit `touch.autoRotate`, nicht bei gesperrter Drehung; `hyprctl eval hl.monitor{... transform}` (normal, left-up=1, bottom-up=2, right-up=3). Beim Verlassen des Tablet-Modus zurück auf 0. Zuordnung der Richtungen ungetestet (kein Kippen möglich).
- **Randwischen** (`EdgeStrip`, 16 px, nur Touch, 60 px Weg): oben = Kontrollzentrum, links = Launcher (Settings `touch.edgeGestures`). Im Tablet-Modus mit versteckter Leiste zeigt der erste Wisch von oben die Leiste (5 s), erst der zweite öffnet die Aktion.
- **Leiste im Tablet-Modus** (`touch.tabletBarAutoHide`): gleitet aus (260 ms), Platz wird frei.
- **Tablet-Modus von Hand (Nachtrag, weil der HP-WMI-Schalter dieses Laptops beim Umklappen nicht meldet, zweimal 60 s gemessen):** Knopf „Tablet“ neben dem Power-Knopf über dem Kontrollzentrum (gefüllt = an) und IPC `tabletToggle`. `DeviceModeState.tabletMode = switchTablet || manualTablet`.
- **Bildschirmtastatur überall** (`services/Osk`, `osk/OskPanel`, `osk/OskWindow`): Textfelder melden ihren Fokus an `Osk.track`; im Tablet-Modus (Einstellung `touch.autoOnScreenKeyboard`) oder nach IPC `oskToggle` erscheint die Tastatur (gleiche wie auf dem Sperrbildschirm, mit Taste ⌄ zum Schließen). Launcher und Kontrollzentrum zeichnen sie selbst (Vollbild-Overlay würde ein eigenes Fenster verdecken), andere Fenster (AI-Leiste, Settings) nutzen das Tastaturfenster. Felder: Launcher, AI-Eingabe, Settings-Suche und -Zeilen, WLAN-Passwort.
- Offen: Dreh-Schalter im Kontrollzentrum, Hinweis beim Drehen (OSD), Tippen über die Tastatur nur per Bildschirmbild geprüft (Tasten von Hand).

### Abschnitt 7b-2 (Greeter, Installer)
- **Greeter** (`greeter/`, `shell/models/GreeterState.qml`): Login-Bildschirm im Stil des Sperrbildschirms (Uhr, Benutzername, Passwortpille, Session, Restart/Shut down, eingebaute Tastatur, optionales Hintergrundbild mit Schleier). Anmeldung über `Quickshell.Services.Greetd` (createSession → Passwort bei der Frage → readyToLaunch → launch). Benutzer aus /etc/passwd (UID 1000..59999, mit Shell), Einstellungen aus `/etc/aptus/greeter.json`, letzter Benutzer/Session in `/var/cache/aptus-greeter/state.json`. Kein Sleep-Knopf.
- **Start:** greetd → `/usr/local/bin/aptus-greeter-session` → `cage -s -- qs -p /usr/local/share/aptus/greeter`. Cage zeigt genau ein Fenster; der Greeter ist deshalb ein normales Vollbildfenster. `bin/aptus-greeter-build DEST` baut den eigenständigen Ordner (greetd-Benutzer kann dein Home nicht lesen): Greeter-Dateien, theme, components, zwei Modelle, drei Teile des Sperrbildschirms, tokens.json.
- **Installer:** `./install.sh --greeter` (fragt, sichert `/etc/greetd/config.toml` als `.before-aptus`, sudo je Schritt, greetd wird nicht neu gestartet), `--uninstall-greeter` stellt zurück; Notweg per Konsole (Strg+Alt+F3) steht in der Ausgabe. `ensure_cliphist` und `check_lid_policy` prüfen nur und sagen, was zu tun wäre. `enable_repos`/`install_packages` bleiben Platzhalter.
- **Geprüft:** Greeter als normales Fenster unter Hyprland (Bild, Benutzer aus /etc/passwd, Session, Tasten), Lint 0 Warnungen, Installer im Trockenlauf. **Nicht geprüft:** echte Anmeldung über greetd und cage (kein sudo hier), Neustart/Herunterfahren aus dem Greeter, Rechte des Benutzers `greetd` für `systemctl reboot`.
- Hintergrundbild für Sperrbildschirm und Greeter kommt mit dem Wallpaper-Picker (7c).

### Abschnitt 7c-1 (Wallpaper)
- Die Shell zeichnet das Hintergrundbild selbst (`wallpaper/WallpaperLayer`, Layer Background, je Bildschirm), kein Wallpaper-Programm nötig. Gewähltes Bild: `~/.local/state/aptus/wallpaper`; Ordner: Setting `wallpaper.directory` (leer = `~/Pictures/Wallpapers`, Settings → Appearance).
- **Picker** (`Mod+W` = `panel-toggle wallpaper`, auch Settings → Appearance → Wallpaper): Raster aus Vorschaubildern auf demselben Blur wie das Kontrollzentrum, Tippen setzt das Bild sofort, erste Kachel „None“, Esc oder Tippen daneben schließt. Leerer Ordner zeigt einen Hinweis.
- **Sperrbildschirm** zeigt das Bild mit hellem Schleier (45 %). **Greeter:** Bild nur über `wallpaper` in `/etc/aptus/greeter.json` (Pfad muss für den Benutzer `greetd` lesbar sein, z. B. unter `/usr/local/share/aptus`); ein „für Login übernehmen“ im Picker braucht sudo und kommt später.
- Zum Testen liegen drei erzeugte Farbverläufe in `~/Pictures/Wallpapers` (löschbar).

### Abschnitt 7c-2 (Settings-Editoren, README)
- **Neue Editoren** in der Settings-App: Suchmaschinen-Liste (Name, URL-Vorlage, hinzufügen, entfernen, mindestens eine bleibt) und Wetter-Ort (Suche über die Open-Meteo-Geokodierung, Tippen übernimmt Name und Koordinaten). Beide sind „breite“ Zeilen mit Editor unter dem Titel (`SettingRow.wide`). `FieldBox` meldet den Fokus an die Bildschirmtastatur. IPC `settingsFocus <entryId>` öffnet die Settings an einem Eintrag.
- **Weiter nur in der Datei** (Hinweis „Edit this in settings.json“): Provider-Liste (AI), Kachel-Reihenfolge, Tastenkürzel, Launcher-Modustasten. Grund: Provider und Kürzel haben eigene Speicherorte und eigene Prüfungen (Befehl testen, Konflikte), Kacheln brauchen ein bewegliches Raster.
- README neu geschrieben (Funktionen, Voraussetzungen, Installation, Tasten, Sicherheit).
- **Entschieden (Lenno):** Lizenz MIT (`LICENSE`); der Punkt im Namen bleibt, das Repo heißt weiter `aptus.`. **Offen:** AI-Nutzung (Gespräch, siehe unten).

### AI-Nutzung (Variante A, Lenno)
- `AiUsageState` liest `~/.claude/usage-cache.json` (Claude Code bzw. das Noctalia-Plugin „claudecode“ pflegt sie), beobachtet die Datei und zählt jede Minute die Uhr weiter. aptus fasst kein Login-Token an und ruft keinen Endpunkt auf.
- Kachel: kompakt 5-h-Fenster mit Balken und 7-Tage-Wert, im Detail beide Fenster mit Reset-Zeit, „diese Woche nach Produkt“ und „Updated vor x min“. Balken ab 70 % amber, ab 90 % rot. Über 30 min alt: „old“ in Amber und Hinweis, dass die Zahlen sich bewegen, wenn Claude Code läuft.
- Ohne Datei: „No usage data“ mit Erklärung. Für `agy` und `vibe` gibt es keine Zahlen. Variante B (Endpunkt mit Token) bleibt eine mögliche spätere Option hinter einem Schalter, nur mit Lennos Okay.

### Abschnitt 7d (Provider, Drehsperre, Unschärfe)
- **Provider-Editor** (Settings → AI): Schalter je Provider (der letzte aktive bleibt an), „Remove“ nur für eigene, „Add a command-line tool“ (Name, Programm, Argumente mit genau einem `{prompt}`; Prüfung vor dem Speichern). Wirkt sofort und liegt in `~/.config/aptus/ai-providers.json` (`providers` und `overrides` für die eingebauten). Der Standard-Provider bietet nur aktive an. Ein Test-Knopf für den Befehl fehlt noch.
- **Drehsperre:** Knopf neben dem Tablet-Knopf über dem Kontrollzentrum (nur im Tablet-Modus; gefüllt = gesperrt), IPC `rotationLockToggle`, OSD „Rotation locked / follows the device“.
- **Unschärfe:** Der Regler „Background blur“ steuert jetzt die Hyprland-Unschärfe (`size = Wert/2`, 2 Durchgänge bis 10, sonst 3), beim Start und bei jeder Änderung. Vorher war der Regler wirkungslos.
- **Tastenkürzel-Übersicht** (Settings → Shortcuts, nur lesen): alle Kürzel aus `config/hotkeys.json` (neu: Mod+X), Überschneidungen in Amber. Geändert wird in `~/.config/hypr/hyprland.lua` bzw. `hypr/binds.generated.lua`; ein Editor würde die Hyprland-Datei des Nutzers oder eine getrackte Repo-Datei umschreiben und kann aussperren, deshalb bewusst nicht. **Provider-Test:** „Test“ prüft, ob das Programm im PATH liegt (kein Aufruf des Modells).
- Weiter nur in der Datei: Launcher-Modustasten, Kachel-Reihenfolge.

### Durchgang (20. Okt.)
- Lint 0 Warnungen/Fehler, Installer-Trockenlauf sauber (Hyprland-Block und shell-switch-Patch erkannt, auch ein neueres shell-switch mit mehr Shells).
- Entfernt: tote Platzhalter (Modelle `AiProvider`, `ChatMessage`, `ContextItem`, `TileSpec`, `NotificationItem`, `SessionInfo`, `SettingsCategory`, `WorkspaceInfo`, `HotkeyBinding`; `IconButton`, `DebugOverlay`, `settings/editors/*`; unbenutzte Funktionen wie `reportHotkeyLatency`, `webSuggestions`, `parseSystemAction`), erledigte TODO-Zeilen, die alte Testliste 4a.
- Neu dabei: **offene Fenster in der Launcher-Suche** (Apps-Modus, Setting „Show open windows“; Enter fokussiert das Fenster, `Compositor.focusWindow`). Entfernt: Setting „Show recent apps“ (nie umgesetzt, wirkungslos).
- Greeter: von Lenno auf dem Laptop installiert, Login läuft („works“); Touch-Tastatur dort ungetestet.
- **Bewusst offen / nur am Gerät prüfbar:** Touch-Wischen, Tablet-Schalter (meldet auf diesem Gerät nicht, Knopf im Kontrollzentrum), Drehrichtungen, Klicks in den Settings, Idle-Sperre, Bildschirm-Aus, Deckel zu, Warnfarben der AI-Nutzung.
- **Noch nicht gebaut:** Kontext-Zone der Leiste mit Medien/Timer/Downloads, „More“-Links in den Dropdowns, Kachel-Reihenfolge-Editor, Launcher-Modustasten-Editor, Hintergrundbild für den Login aus dem Picker, Web-Vorschläge, System-Aktionen in der Suche (`wifi off`, `timer 10m`), `enable_repos`/`install_packages` im Installer, Variante B der AI-Nutzung (nur mit Lennos Okay).

### Baustein 1: Kontext-Zone (20. Okt.)
- `ContextState` (services) liefert Einträge: Akku kritisch 90, Timer 60, Notification 40 (hängt am Popup), Musik 30 (nur spielend); sonst Fenstertitel. Klick öffnet die Kachel. Aufnahme bewusst nicht (roter Punkt rechts). Geprüft per Screenshot nur mit Notification; Timer, Musik, Klick, Elide am Gerät offen.

### Baustein 2: „More“-Links (20. Okt.)
- Audio, Battery, Clock, NightLight haben unten die Zeile „More“ (wie Bluetooth/Network) und öffnen die Kachel Audio, PowerProfile, Calendar, Display. `DropdownHost` leitet das Signal weiter. Lint 0 neue Warnungen, Shell lädt ohne Fehler; Optik und Klick am Gerät offen (kein IPC zum Öffnen eines Dropdowns).

### Baustein 3: Kachel-Editor (20. Okt.)
- `TileCatalog` (controlcenter, Singleton): alle 17 Kacheln mit fester Größe, `normalize` (unbekannte/doppelte raus, neue ans Ende), `layout` packt die sichtbaren Kacheln in Listenreihenfolge je auf den ersten freien Platz (6 Spalten, Zeilen dynamisch, mindestens 3). Standardreihenfolge ergibt dasselbe Raster wie vorher.
- Settings → Control Center → Tiles: `TileListEditor` mit Schalter sichtbar und Up/Down, läuft durch Entwurf/Speichern/15-s-Bestätigung. Wert `controlCenter.tiles` = Liste `{ key, visible }` (alter, nie gelesener Wert ersetzt).
- Ausgeblendete Kachel lässt sich per Kontext-Zone/More trotzdem öffnen (Detail wächst aus der Brettmitte).
- Geprüft: Lint 17 (unverändert), Control Center Screenshot = altes Raster, Editor Screenshot, Packen per Python-Spiegel mit versteckten Kacheln. Nicht geprüft: Speichern, Umordnen und Ausblenden live am Gerät.

### Baustein 4: Modustasten-Editor (20. Okt.)
- Settings → Shortcuts → Launcher mode keys (advanced): `ModeKeyEditor`, Zeile antippen, Kombination drücken. Esc bricht ab, Taste ohne Ctrl/Alt/Meta wird abgelehnt (sie würde ins Suchfeld tippen), Doppelbelegung in Amber („Also used by …“). `Keys.onShortcutOverride` hält Esc und Ctrl+F des Fensters während der Aufnahme fern. Läuft durch Entwurf/Speichern/Bestätigung.
- `AiPanel` las die Werte schon aus den Settings (Handoff-Hinweis „fest“ war überholt).
- Geprüft: Lint 17 (unverändert), Screenshot der Zeilen. Nicht geprüft: Aufnahme per Klick und Tastatur (kein Zugriff per ydotool), Wirkung im Launcher nach Speichern.

### Baustein 6: System-Aktionen in der Suche (20. Okt.)
- `Search.searchActions` (Apps-Modus, vor Fenstern und Programmen): `wifi`, `bluetooth`, `night light`, `caffeine`, `focus`/`do not disturb` mit optionalem `on`/`off` (ohne: Zustand umschalten, Zeile zeigt „Currently on“), `lock screen`, `timer 10m` (auch `1h30`, `90s`, `25` = Minuten), `stop timer` (nur bei laufendem Timer), `pomodoro`. Dienste kommen über `Search.controls` aus `shell.qml`.
- Bewusst nicht: Restart, Shutdown, Log out per Tippen (unwiderruflich, ein Enter zu nah); dafür gibt es das Power-Menü.
- Geprüft: Lint 17, Dauer-Parser in Node (13 Fälle, ein Fehler bei `90s` gefunden und behoben), live im Launcher: `wifi` zeigt „Turn Wi-Fi off“, `timer 90s` + Enter startet den Timer, die Kontext-Zone zeigt „1:29 Timer“ (bestätigt Baustein 1), `stop timer` beendet ihn. Nicht live geprüft: die anderen Schalter auszuführen (Wi-Fi/Bluetooth würden die Verbindung kappen).

### Baustein 5: Web-Vorschläge (20. Okt.)
- `WebSuggest` (services, Singleton): holt Vorschläge per `curl` (Argumentliste, keine Shell) beim Dienst der gewählten Suchmaschine (Google, DuckDuckGo, Bing; eigene Maschinen bekommen keine), 150 ms entprellt, veraltete Antworten werden verworfen (`forQuery`). Aus Search-Sicht zeigt der Web-Modus „Search the web“ plus bis zu 8 Vorschläge (`WebSuggestion`).
- Datenschutz: Schalter `launcher.webSuggestions`, **Standard aus**, Beschreibung nennt, dass jede getippte Zeile an die Suchmaschine geht.
- Launcher ergänzt die Liste nachträglich (`onSuggestionsChanged`) und behält die Auswahl.
- Geprüft: Lint 17, beide Antwortformate per curl (Google und DuckDuckGo `type=list` liefern `["q",[…]]`), live im Web-Modus mit Schalter an (Screenshot: Vorschläge unter der Suche). Bing-Endpunkt nicht abgefragt.

### Baustein 8: Installer (20. Okt.)
- `install_packages`: fehlende Pakete aus `REQUIRED_PACKAGES` (quickshell, hyprsunset, brightnessctl, playerctl, grim, slurp, wl-clipboard, cliphist, curl, power-profiles-daemon, NetworkManager, iio-sensor-proxy, wf-recorder, libnotify, python3) per `rpm -q` finden, Liste zeigen, fragen, `sudo dnf install -y`. Nicht in den Repos Verfügbares geht nur mit `--copr` (fragt, `sudo dnf copr enable lionheartp/Hyprland`; `--yes` schaltet das COPR nie von selbst frei). Quickshell-Version ≥ 0.3.2 wird geprüft (Warnung).
- `--uninstall`: entfernt die Links auf diesen Ordner und spielt `.before-aptus` zurück, stellt shell-switch wieder her, entfernt den Hyprland-Block (Sicherung `.before-uninstall`); lässt Einstellungen, State-Ordner, Pakete und Greeter in Ruhe. Flags dürfen in beliebiger Reihenfolge stehen (Fehler behoben: `--uninstall-greeter --dry-run` brach vorher vor `--dry-run` ab).
- `ensure_cliphist` entfällt (steckt jetzt in der Paketliste).
- Geprüft: `bash -n`, Trockenläufe `--dry-run`, `--dry-run --yes`, `--uninstall --dry-run --yes` auf dem Laptop (nur cliphist fehlt dort). Echte `dnf`-Läufe und echte Deinstallation nicht ausgeführt.

### Baustein 7: Login-Hintergrund aus dem Picker (20. Okt.)
- `bin/aptus-greeter-wallpaper` (Python, läuft als root über `pkexec`): liest das Bild mit den Rechten des Aufrufers (`setpriv`, `PKEXEC_UID`), nimmt nur jpg/png/webp bis 32 MB (Magic Bytes), schreibt atomar nach `/usr/local/share/aptus/wallpaper.<ext>` und setzt `wallpaper` in `/etc/aptus/greeter.json`; `--clear` entfernt es. Polkit-Aktion `config/polkit/org.aptus.greeter-wallpaper.policy`. `install.sh --greeter` installiert beides, `--uninstall-greeter` entfernt beides.
- Picker: Knopf „Use for login screen“ (bei „None“: „Remove login picture“), nur sichtbar, wenn der Helfer installiert ist; Status Working / updated / Failed. Abbruch des Passwortdialogs (pkexec 126) zeigt keinen Fehler.
- **Neu, weil keine Polkit-Oberfläche lief:** `PolkitPrompt` (session) registriert aptus als Polkit-Agent der Sitzung (Quickshell `PolkitAgent`): Dimmer, Meldung, Passwortfeld, Cancel/Authenticate, Esc bricht ab. Läuft schon ein anderer Agent, bleibt es unsichtbar.
- Geprüft: Lint 17 (unverändert), `bash -n`, Skriptlogik in einer Kopie mit Attrappen (jpg ok, Textdatei und fehlende Datei abgelehnt, `--clear`), Shell startet ohne Fehler. **Nicht geprüft:** Passwortdialog (Test per `pkexec true` bewusst nicht ausgeführt), der Lauf als root mit `setpriv`, Greeter mit neuem Bild, `install.sh --greeter` mit den neuen Zeilen. Der Knopf erscheint erst nach erneutem `install.sh --greeter`.

### Baustein 9: AI-Nutzung live, Variante B (20. Okt., mit Lennos ausdrücklichem Okay)
- `bin/aptus-ai-usage` (Python): liest `claudeAiOauth.accessToken` aus `~/.claude/.credentials.json`, fragt `https://api.anthropic.com/api/oauth/usage` ab und gibt nur JSON (`{cached_at, data}` oder `{error}`) aus. Der Token bleibt im Helferprozess: er geht per stdin (`curl -K -`) an curl, taucht in keiner Prozessliste auf, wird nie ausgegeben, geloggt oder geschrieben und **nie erneuert** (eine Erneuerung rotiert das Refresh-Token und könnte Claude Code ausloggen). Abgelaufen: `{"error": "expired"}`, Claude Code einmal benutzen erneuert ihn. Honest User-Agent `aptus`.
- `AiUsageState`: Schalter `ai.usageLive` (**Standard aus**, Settings → AI, Beschreibung nennt Token, Ziel, inoffiziellen Endpunkt), Abruf alle 5 Minuten, Ergebnis über dasselbe `load()` wie die Cache-Datei; eine ältere Datei überschreibt keine frischere Antwort. Fehler zeigt die Kachel in Amber („Live numbers paused: the Claude login has expired…“), die Zahlen aus der Datei bleiben.
- Installer verlinkt `aptus-ai-usage` nach `~/.local/bin` (auf dem Laptop von Hand verlinkt).
- Geprüft: Helfer direkt (50 % / 15 % gegen 26 % / 12 % im Cache), Lint 17, Kachel live mit Schalter an (Screenshot, kein „old“), Shell-Log ohne Token. Nicht geprüft: Verhalten bei abgelaufenem Token und ohne Netz am echten Gerät (Pfade nur im Code).

## Notch (neue Funktion, zweiter Phasenablauf, 22. Okt.)

### Phase 1: Verstehen und planen

**Ziel (Lenno):** Ein Notch oben am Bildschirm als **Alternative** zur Leiste. In den Einstellungen wählt man, ob man Leiste oder Notch will. Aussehen und Gefühl zählen mehr als Umfang. Außerdem will Lenno sich das Theming und die Farben des Vorbilds ansehen, um zu entscheiden, ob davon etwas in aptus soll.

**Vorbild:** `ciscobugger/tacit` (Arch-Distro mit Quickshell-Desktop). Dort heißt das Ding „island“ bzw. Notch (`modules/ii/island`, Einstellungen `NotchConfig.qml`). Nur zum Ansehen geklont. **Lizenz:** tacit steht unter GPL-3.0, aptus unter MIT. Deshalb wird **kein Code, kein Text, kein Name und keine Konstante übernommen**; aptus bekommt eine eigene Umsetzung und eigene Gestaltung (passt auch zu Lennos Vorgabe „eigene Ideen“).

**Was die Idee bei tacit ausmacht (nur das Konzept):**
- Kleine Pille oben mittig im Ruhezustand. Bei Ereignissen (Benachrichtigung, Lautstärke, Helligkeit, Akku, Netz, Workspace-Wechsel, Timer, Download, lange Jobs) wird sie kurz breiter, sagt eine Zeile und wird wieder still.
- Antippen oder Hover klappt sie zu einem Blatt mit Details auf (Musik mit Wellenform, Timer, Verlauf).
- Schalter „Leiste ausblenden, der Notch ersetzt sie“; Abstand zum Rand; reservierte Höhe; Anzeige über Vollbild nur bei laufender Musik.
- Technik: ein Fenster pro Bildschirm in fester Größe, nur der Inhalt bewegt sich, alles außerhalb ist per Maske klick-durchlässig (Hyprland animiert Größenänderungen von Layer-Fenstern, das ließ den Notch „schwimmen“).
- Theming bei tacit: Farben folgen dem Hintergrundbild (matugen-Palette); Textstufen entstehen über Helligkeit mit festem Kontrast (APCA), nie über Transparenz; Farbe hat feste Bedeutung (Akzent = Standard-Aktion, Risiko-Farbe nur mit Warnzeichen). Das ist das Gegenteil von aptus („Palette neutral, Farbe nur als Zustand, feste Palette mit Nachtlicht-Verschiebung“).

**Was aptus schon hat (wird wiederverwendet):**
- `ContextState` liefert schon priorisierte Einträge (Akku kritisch 90, Timer 60, Benachrichtigung 40, Musik 30) mit Schweregrad und Ziel-Kachel. Das sind die „Meldungen“ des Notch.
- `StatusGroup`, `WorkspaceStrip`, `Clock`, `BarItem` und die Dropdowns (`DropdownHost.openAt(id, anker, screen)`) sind fertig, nur an die Leiste gebunden.
- Das Settings-System (Entwurf → Speichern → 15 s Bestätigung → Rücknahme durch Watchdog) schützt das Umschalten Leiste/Notch automatisch vor Aussperren.

**Konzept (Vorschlag, eigene Gestaltung):**
- **Umschalter:** Einstellung `bar.style` (`bar` | `notch`, Standard `bar`), Settings → Bar, ganz oben. Immer nur eines ist aktiv. Wechsel ohne Neustart (die jeweils andere Fläche wird nicht geladen). Weitere Notch-Einstellungen nur sichtbar, wenn Notch gewählt ist.
- **Drei Zustände:** *Ruhe* (kleine Pille mit Uhr und, wenn nötig, einem Zustandspunkt), *Meldung* (breiter, eine Zeile aus `ContextState`, 260 ms hin, 140 ms zurück, geht von selbst zurück), *Offen* (aufgeklappt: Workspaces, Status-Symbole mit den bekannten Dropdowns, Kontextzeile/Musik, Knöpfe Control Center und Launcher).
- **Bedienung:** Antippen/Klick öffnet, Esc schließt (eine Stufe zurück, wie überall). Hover-Öffnen nur als Option (Standard aus, Touch-Regel: nichts hängt an Hover). Die Ruhe-Pille ist optisch klein, die Trefferfläche mindestens 40 px.
- **Platz:** Standard reserviert der Notch dieselbe Höhe wie die Leiste (28 px), damit Fenster beim Umschalten nicht springen; neben der Pille ist der Streifen durchsichtig (Hintergrundbild). Option „über Fenstern schweben“ (advanced).
- **Tablet:** Wie die Leiste: im Tablet-Modus automatisch weg, Wischen von oben bringt ihn zurück (`barAutoHidden` gilt für beide).
- **Look (aptus-Regeln bleiben):** deckend, kein Glas, Haarlinie statt Schatten, Farbe nur als Signal, Radius Pille 999, obere Kante bündig am Bildschirmrand, 140/260 ms, Kurve [0.2, 0, 0, 1]. Zwei Varianten zur Wahl (Entscheidung nach Mockup): **A** helle Fläche (`Tokens.surface`) mit Haarlinie, **B** Tinte (`Tokens.ink`) mit hellem Text, wie ein echter Notch; beide folgen dem Nachtlicht.
- **tacit-Farbthema:** nicht Teil dieses Auftrags, weil es Lennos Vorgabe „Palette neutral“ umkehrt. Als eigene, spätere Option `appearance.palette` (`neutral` | `wallpaper`) denkbar. Zum Ansehen zeigt das Look-Mockup beide Fassungen nebeneinander; Lenno entscheidet danach.

**Betroffene Dateien (Plan):**
- Neu: `shell/notch/` mit `Notch.qml` (Fenster je Bildschirm, feste Größe, Maske), `NotchRest.qml`, `NotchAlert.qml`, `NotchSheet.qml`, `qmldir`; `shell/models/NotchState.qml` (Zustand: Ruhe/Meldung/Offen, aktuelle Meldung, Haltezeit).
- Neue Typen: `Enums.NotchStage { Rest, Alert, Open }`; Einstellungen `bar.style`, `notch.hoverOpen`, `notch.reserveSpace`, `notch.look` (a | b), `notch.showClock` in `config/settings.json` und `config/settings-schema.json` (Art `choice` und `toggle` gibt es schon, kein neuer Editor).
- Geändert: `shell/shell.qml` (Leiste nur bei `bar`, Notch nur bei `notch`, `barAutoHidden` für beide), `shell/IpcHandlers.qml` (`notchToggle`, `notchOpen`), `config/hotkeys.json` (optional, Taste offen), `bin/aptus` (kebab-case-Übersetzung prüfen).
- **Bindung an die Leiste lösen:** `Tokens.barHeight` steckt in `DropdownHost` (Rand oben), `AiPanel` (Rand oben), `NotificationPopups` (Abstand), `ControlCenter` (y-Start) und in den Leistenteilen (`BarItem`, `Clock`, `WorkspaceStrip`, `StatusGroup`, `ContextZone` als `implicitHeight`). Plan: ein Wert `ShellState.topInset` (Leiste = 28, Notch = Reserve), die vier Fenster lesen ihn statt `Tokens.barHeight`; die Leistenteile bekommen eine eigene Höhen-Property, damit sie im Sheet wiederverwendbar sind.

**Risiken und offene Technik:**
1. **Dropdown-Verankerung:** `openAt` nutzt nur die x-Lage des Ankers; das Dropdown-Fenster beginnt bei `Tokens.barHeight`. Im Notch-Modus muss es unter dem Sheet oder unter der Pille erscheinen, ohne dass das Sheet es verdeckt. Wahrscheinlich: Sheet schließt, Dropdown öffnet unter der Pille. In Phase 5 am Gerät ausprobieren.
2. **Vollbild:** Hyprland legt die Top-Ebene unter Vollbild-Fenster; der Notch ist dort unsichtbar (Idle-Sperre bleibt durch den Inhibitor aktiv). Optional später Overlay-Ebene.
3. **Mehrere Bildschirme:** Leiste läuft heute je Bildschirm. Vorschlag: Notch ebenso (Entscheidung offen).
4. **Doppelte Meldungen:** OSD-Pille und Benachrichtigungs-Popups gibt es schon. Version 1 lässt sie unverändert; der Notch zeigt nur die Kontextzeile. Ob sie später im Notch aufgehen, ist offen.
5. **Rückmeldung ≤ 50 ms:** Der Notch wird vorab geladen und nur in Größe und Deckkraft animiert (kein Laden beim Öffnen).
6. **Lint:** Basis sind 17 Warnungen (`./aptus-lint.sh`); keine neuen.
7. **Nicht prüfbar ohne Laptop:** Gefühl der Animation, Touch-Treffer, Verhalten unter Hyprland 0.56. Alles Gebaute wird auf dem Laptop per Screenshot geprüft, wie bisher.

**Phasenplan Notch:**
- Phase 1b (auf Wunsch zuerst): **Look-Mockup** als statisches HTML (`docs/mockups/notch.html`): Ruhe, Meldung, Offen, Varianten A/B, Tag und Nacht, dazu das tacit-Farbthema zum Vergleichen. Das ist die Grundlage für Lennos Look-Entscheidung.
- Phase 2: Strukturen (`NotchStage`, `NotchState`-Properties, Einstellungs-Schlüssel, leere Komponenten mit Properties, `qmldir`).
- Phase 3: Signaturen (`NotchState.show/open/close/alert/…`, IPC-Funktionen, `ShellState.topInset`), alle mit Platzhalter.
- Phase 4: TODO-Marken an `shell.qml`, `DropdownHost`, `AiPanel`, `NotificationPopups`, `ControlCenter`, `IpcHandlers`.
- Phase 5: Probe-Implementierung auf dem Laptop (wird wieder verworfen), Lücken zuordnen.
- Phase 6: Invarianten (z. B. nie Leiste und Notch gleichzeitig, Meldung nie im Zustand Offen, `topInset` ≥ 0).
- Phase 7: Umsetzung in Abschnitten: N1 Umschalter, Fenster, Ruhe; N2 Offen mit Status, Workspaces, Dropdowns; N3 Meldungen aus `ContextState`; N4 Feinschliff Look nach Lennos Test.

**Entscheidungen, die Lenno treffen sollte (mit Vorschlag):**
1. Form: an den oberen Rand gehängt, obere Ecken gerade (Vorschlag) oder schwebend mit Abstand?
2. Ruhe-Inhalt: Uhr (Vorschlag), nur ein Punkt oder Fenstertitel?
3. Öffnen: Tippen/Klick (Vorschlag), Hover als Option.
4. Platz: wie Leiste reservieren, 28 px (Vorschlag), oder schweben?
5. Meldungen: nur Kontextzeile (Vorschlag) oder auch OSD und Popups im Notch?
6. Mehrere Bildschirme: je Bildschirm (Vorschlag) oder nur der fokussierte?
7. Look A (hell) oder B (Tinte): nach dem Mockup.
8. tacit-Farbthema (Palette aus Hintergrundbild): nur ansehen oder als spätere Option planen?

Review: Phase 1 hat kein Review (laut Skill).

## Bild-Theming (neue Funktion, dritter Phasenablauf, 22. Okt.)

**Ziel (Lenno):** Weg von festen „Material You“-artigen Paletten. Gewünscht ist ein **Stil**, den man einstellt: **Wasserfarbe** oder **Öl**. Die Farben kommen automatisch aus dem Hintergrundbild, der Stil dämpft sie und macht sie weich. Weiß wird Off-White oder Beige. Gemeint ist die Stimmung gedeckter Outdoor- und Laufmode-Farben: Oliv, Khaki, Stein, Salbei, Tonerde, wie bei Camo-Tönen, bedeckt statt bunt. Die **Leiste** ist einstellbar (Off-White oder mit Bildfarbe getönt). „Farbe nur funktional“ gilt für Icons und Knöpfe, die Shell selbst darf Farbe tragen. Aussehen und Gefühl vor Umfang.

**Entscheidung gegenüber früher:** Die Vorgabe „Palette neutral“ gilt nur noch für Icons und Knöpfe. Das Farbthema aus dem Notch-Plan (`appearance.palette`, neutral | wallpaper) ist damit durch diese Umsetzung ersetzt. Es wurde nichts aus tacit übernommen (GPL-3.0), Verfahren und Werte sind eigene.

**Vorlage:** Live-Mockup „shell. Theming“ (Artifact in der Claude-Sitzung vom 22. Okt.). Seine Zahlen stehen jetzt als Parameter in `theme/tokens.json` unter `themeStyles`. Lenno hat das Mockup freigegeben („genauso einbauen“).

**Verfahren:**
1. Quelle: Bild (`wallpaper`), eingebaute Farben des Stils (`fixed`, `fallbackColors`) oder die bisherige neutrale Palette (`standard`, Standardwert, Aussehen bleibt wie bisher).
2. Aus dem Bild vier deutlich verschiedene Farben lesen (verkleinerte Kopie, Clustern, Gewichtung nach Menge und Sättigung; `themeExtraction`).
3. Der Stil rechnet um: Sättigung stark runter, Wasserfarbe heller und leicht kühl (Zielton 205°), Öl dichter und wärmer (Zielton 35°). Daraus Papier, Fläche, Linie, Tinte, drei Textstufen, vier Kachel-Lasuren, Auswahl, Glasfüllung, Leiste.
4. `ok`, `warn`, `critical` bleiben feste, gedämpfte Pigmente je Stil.
5. Korn nur auf großen Flächen: Papier (Wasserfarbe), Leinwandgewebe (Öl). Nie auf Leiste und Dropdowns.
6. Nachtlicht: Die Mischung Tag/Nacht (`Tokens.blend`) wirkt weiter auf das Ergebnis (Plan für Phase 3: erst Stilfarben berechnen, dann Nachtlicht darüber).

**Einstellungen (neu):** `appearance.themeSource` (standard | fixed | wallpaper), `appearance.style` (watercolor | oil), `bar.tone` (offwhite | tinted). Alle drei laufen durch das Speichern mit 15 Sekunden Rückfrage.

**Phasenplan:**
- Phase 1: Plan und Mockup. **Erledigt.**
- Phase 2: Strukturen. **Erledigt** (siehe unten).
- Phase 3: Signaturen. **Erledigt** (siehe unten).
- Phase 4: TODO-Markierungen. **Erledigt** (siehe unten).
- Phase 5: Probe-Implementierung (Rechnung als Node-Test gegen die Mockup-Werte, dann auf dem Laptop mit echten Bildern), danach zurückgesetzt.
- Phase 6: Invarianten: beide Stile haben dieselben Schlüssel, Tinte auf Fläche mindestens 4,5 zu 1, Quelle `wallpaper` ohne lesbares Bild fällt auf `fallbackColors` zurück, nie ohne Farben.
- Phase 7: Umsetzung und Test auf dem Laptop.

### Phase 2: Strukturen (erledigt)
- `Enums.qml`: `ThemeSource { Standard, Fixed, FromWallpaper }`, `ThemeStyle { Watercolor, Oil }`, `BarTone { OffWhite, Tinted }`. „Neutral“ wäre mit `Severity.Neutral` kollidiert, deshalb `Standard`.
- `config/settings.json` und `config/settings-schema.json`: die drei Einstellungen, Standardwerte `standard`, `watercolor`, `offwhite`. Art `choice`, kein neuer Editor nötig.
- `theme/tokens.json`: `themeStyles` (watercolor, oil, gleiche 20 Schlüssel) und `themeExtraction`.
- `Tokens.qml`: Properties `themeSource`, `themeStyle`, `barTone`, `styles`, `extraction`, `bar`, `barInk`, `wash1..4`, `selection`, `glass`, `grain`. Die Standardwerte entsprechen der bisherigen Palette.
- Neu: `shell/models/WallpaperColors.qml` (`path`, `entries`, `ready`, `failed`), in `qmldir` eingetragen. `Wallpaper.qml` hält `colors`.
- `AppSettings.qml`: `themeSource`, `themeStyle`, `barTone`.
- Nichts verdrahtet: `Bar.qml` und alle Kacheln nutzen weiter die alten Tokens, das Aussehen ändert sich noch nicht.

**Review Phase 2** (ohne Sub-Agenten, per Prüfskript): JSON gültig; jeder Schema-Pfad existiert in `settings.json`, keine doppelten Ids; die drei neuen Werte stehen in ihren Optionen; beide Stile haben dieselben Schlüssel; keine neuen Enum-Wertkollisionen (die schon vorhandenen, z. B. `None` in mehreren Enums, sind älter und unverändert); keine Funktion in den neuen Dateien. Nicht prüfbar: `qmllint` und Quickshell sind hier nicht installiert, ob `readonly property WallpaperColors colors: WallpaperColors {}` im Singleton und `import qs.models` in `Wallpaper.qml` bei dir durchgehen, zeigt erst der Lauf (Phase 5).

### Phase 3: Signaturen (erledigt)
Alle neuen Funktionen haben einen Platzhalter-Körper (`throw new Error("not implemented")`).
- Neuer Singleton `shell/services/ThemeSource.qml` (in `qmldir` eingetragen): `read(path)` (Bildfarben lesen, setzt `Wallpaper.colors`), `extract(rgba, options)` (rein, wählt vier Farben, ohne Quickshell testbar), `fallbackEntries(style)`.
- `Tokens.qml`: `refreshTheme()` (Quelle wählen, berechnen, anwenden), `styleColors(style, entries, tone)` (rein, liefert alle Farben des Stils), `applyStyle(colors)`, `nightShift(c, blend)` (Nachtlicht auch auf Stilfarben), Farbrechnung `hexToHsl`, `hslToHex`, `shiftHue`.
- `AppSettings.qml` bekommt in dieser Phase keine Signatur: Das Laden der drei Einstellungen geschieht in der bestehenden Funktion `refreshViews()` (Nachschlagetabellen wie bei `aiDockEdge`). Das ist Logik in einem bestehenden Körper und gehört deshalb als TODO in Phase 4 und in die Umsetzung (Phase 7).

**Review Phase 3** (ohne Sub-Agenten, per Prüfskript und Diff): Der Diff enthält nur hinzugefügte Zeilen (38), keine bestehende Funktion wurde verändert. Tokens hat 12 Funktionen, davon 7 neue mit Platzhalter; ThemeSource 3 von 3. Kein Funktionsname kollidiert mit einer Property. Keine Aufrufe, keine neuen Properties oder Typen.
- Notiert für Phase 5: Reihenfolge der Berechnung klären. Vorschlag: `styleColors` mit Tagfarben, danach `nightShift` mit `Tokens.blend`. `applyPalette(blend)` darf bei Quelle ungleich Standard die Stilfarben nicht überschreiben.
- Nicht prüfbar: `qmllint`/Quickshell nicht installiert; ob `refreshTheme` als Funktionsname im Singleton `Tokens` mit `applyPalette` und `load` sauber zusammenspielt, zeigt der Lauf.

### Phase 4: TODO-Markierungen (erledigt)
23 Zeilen `TODO(phase 7, Bild-Theming): ...` in 19 Dateien (je höchstens zwei Zeilen), nur Kommentare:
- **Ablauf:** `Tokens.load` (nach `applyPalette` `refreshTheme` aufrufen), `Tokens.applyPalette` (bei Stil als Quelle Stilfarben nicht überschreiben), `NightLightState.onBlendChanged` (`refreshTheme` statt `applyPalette`), `Wallpaper.setWallpaper` und Start (`ThemeSource.read`), `AppSettings.refreshViews` (drei Einstellungen laden und weitergeben).
- **Leiste:** `Bar.qml` (Füllung `Tokens.bar`, Text `Tokens.barInk`), `BarItem`, `Clock`, `ContextZone`, `StatusGroup`, `WorkspaceStrip` (Text und Icons).
- **Flächen:** `Tile.qml` (`wash1..4` nach Kachelposition), `ControlCenter.qml` und `Launcher.qml` (Schleier `Tokens.glass`, Korn), `Pill.qml` und `ListRow.qml` (`Tokens.selection`), `LockSurface.qml` (Glas, Korn), `GreeterSurface.qml` (Entscheidung offen, siehe unten).
- **Sonst:** `SettingsAppState.visibleEntries` (Stil und Leistenton ausblenden, solange die Quelle `standard` ist), `hypr/aptus-look.lua` (Rahmenfarben).

**Review Phase 4** (ohne Sub-Agenten): Der Diff hat 23 hinzugefügte Zeilen, 0 entfernte, und jede hinzugefügte Zeile ist ein TODO-Kommentar. Kein Code, keine Typen, keine Signaturen verändert.

**Lücken, gemeldet statt still behoben (gehören in Phase 2/3, Phase 5 bestätigt sie):**
1. **`surfaceAlt` fehlt im Stil.** 25 Dateien nutzen `Tokens.surfaceAlt`, aber `themeStyles` und das Ergebnis von `styleColors` kennen keinen Wert dafür (Phase 2 und 3). Vorschlag: aus Papier und Linie mischen (`mix(paper, line, 0.5)`), ohne neues Token.
2. **`barInkSoft` und `barInkFaint` fehlen.** Leistentext braucht gedämpfte Stufen auf der (getönten) Leiste. Vorschlag: als Mischung `mix(barInk, bar, 0.4 und 0.6)` im Code, ohne neue Tokens. Alternative: zwei neue Tokens (Phase 2).
3. **Kachel-Lasur nach Position:** `Tile` hat keine Property dafür. Vorschlag: Ausdruck `(column + row) % 4` aus `TileSpec`, ohne neue Property. Alternative: `washIndex` in `TileSpec` (Phase 2).
4. **Bedingte Sichtbarkeit in der Settings-App:** Das Schema hat kein Feld, das einen Eintrag nur bei bestimmtem Wert eines anderen zeigt. Vorschlag: Feld `visibleWhen` im Schema (Phase 2), sonst feste Regel in `visibleEntries`.
5. **Greeter:** Er hat keine Nutzereinstellungen. Entscheidung in Phase 5: `standard` oder Stil mit `fallbackColors`.
6. **Korn-Bilder:** `theme/grain-paper.png` und `theme/grain-weave.png` müssen noch erzeugt werden (Phase 7, kachelbar, klein).

## Nächster Schritt

**Bild-Theming:** Lennos „weiter“, dann Phase 5 (Probe-Implementierung, danach zurückgesetzt).

**Notch:** Lennos Antworten auf die acht Fragen (oder „nimm die Vorschläge“), dann Phase 1b (Mockup) und Phase 2. Sonst:

Alle Bausteine 1 bis 9 aus dem Handoff sind gebaut. Alltagsgebrauch auf dem Laptop, Rückmeldung zu den „Am Gerät offen“-Punkten der Bausteine, dann Feinschliff. README-Screenshot wäre ein guter Abschluss.
