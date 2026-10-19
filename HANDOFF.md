# HANDOFF: was noch fehlt (Stand 20. Okt. 2026, Commit `99b2a65`)

Für einen neuen Chat. Erst `CLAUDE.md` und `PHASES.md` lesen, dann diese Datei. Alles hier ist **nicht gebaut**. Gebaut, getestet und gepusht ist alles aus PHASES.md bis „Durchgang (20. Okt.)“.

## Arbeitsweise (kurz, steht auch in CLAUDE.md)

- Antworten auf Deutsch, knapp, Caveman ultra (globale CLAUDE.md von Lenno), Berichte enden mit „sage weiter“. Nach jedem Abschnitt anhalten, Lenno testet am Laptop. Kein Sub-Agent, außer er verlangt es.
- Aussehen und Gefühl sind fast wichtiger als der Umfang. Eigene Ideen, nicht von anderen Shells abschauen. Farbe nur als Signal (grün ok, amber Achtung, rot kritisch), nur auf kleinen Elementen. Animationen 140/260 ms, Kurve `[0.2, 0, 0, 1]`. Nie Suspend/Hibernate.
- Shell neu starten: `kill $(pgrep -x qs); (setsid qs -p shell > /tmp/claude-1000/aptus.log 2>&1 &)` im Repo-Ordner. IPC: `qs ipc -p shell call aptus <funktion> [args]` (`panelOpen` braucht 2 Argumente, z. B. `panelOpen control-center ""`). Screenshot: `grim -o eDP-1 datei.png`, dann die PNG lesen. Lint: `./aptus-lint.sh` (Ziel 0 Warnungen). Log: `/tmp/claude-1000/aptus.log`.
- **Vorsicht:** `pkill -f` und `pkill -x qs` erwischen die eigene Shell-Zeile oder alle Quickshell-Instanzen. Mit `kill $(pgrep -x qs)` arbeiten. `ydotool` tippt in das fokussierte Fenster, also auch in Lennos Terminal: nicht blind tippen. Klicks und Hover per ydotool erreichen die Shell nicht; Zustände lassen sich per IPC, erzwungene Eigenschaft oder Screenshot prüfen. Temporäre IPC-Funktionen zum Testen vor dem Commit wieder entfernen.
- Hyprland ist 0.56 mit Lua-Konfiguration (`hl.bind`, `hl.dsp.*`, `hyprctl eval '<lua>'`). Lennos Binds rufen `shell-switch msg <befehl>`; `bin/aptus msg` übersetzt kebab-case in `panelToggle` usw.
- qmllint-Regeln: `pragma ComponentBehavior: Bound` bei verschachtelten Komponenten und Inline-Komponenten; Eigenschaftsnamen dürfen keine `QQuickItem`-Member verdecken (`top`, `add` bei Positionern); `margins` und Wayland-Typen mit `// qmllint disable unresolved-type unqualified` umschließen; kein zweites `Component.onCompleted` im selben Objekt.
- Commit-Endung: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Nach jedem Abschnitt PHASES.md aktualisieren, committen, pushen (Repo `github.com/LennoWeber/aptus.`, Branch `main`).

## Baustein 1: Kontext-Zone der Leiste (zuerst empfohlen)

**Ziel:** Die Mitte der Leiste zeigt, was gerade wichtig ist, statt nur den Fenstertitel: laufende Musik, Timer, Downloads, Akku-Warnung, Aufnahme, Benachrichtigung. Wechsel per Überblendung (140 ms), nie ein Aufpoppen. Wenn nichts wichtig ist: Fenstertitel wie heute.

**Stand:** `shell/bar/ContextZone.qml` hat die Auswahl schon: `items` (Liste mit `text`, `severity`, `priority`), `pickCurrent()` wählt die höchste Priorität über `priorityThreshold`, sonst `fallbackText` (Fenstertitel). Es fehlt: nichts füttert `items`. `Bar.qml` hat `property var contextItems`, `shell.qml` setzt es nicht (nur `windowTitle: Compositor.activeTitle`). Das Modell `ContextItem` wurde im Durchgang gelöscht (war ein ungenutzter Platzhalter); Einträge sind einfache Objekte `{ id, text, severity, priority, iconName?, onClick? }`.

**Daten sind alle da:** `MediaState` (`available`, `playing`, `title`, `artist`), `TimerState` (`running`, `remainingSec`, `phaseName`), `BatteryState` (Prozent, `discharging`, Schwellen 20/10), `CaptureState` (`recording`, `recordingSec`; die Leiste zeigt schon einen roten Punkt rechts), `Notifications` (Singleton, `unreadCount`, `items`), Downloads gibt es noch nicht (weglassen oder später).

**Vorschlag:**
1. Eine kleine Zustandsklasse `ContextState` in `shell/services/` (oder in `shell.qml` ein berechnetes `property var contextItems`), die die Quellen zu Einträgen macht. Prioritäten: Akku kritisch 90, Timer läuft 60 (mit Restzeit „12:30 Focus“), Aufnahme 50, ungelesene Benachrichtigung 40 (kurz, dann zurück), Musik spielt 30 („Titel · Künstler“), sonst Fenstertitel.
2. Klick auf den Eintrag öffnet die passende Kachel im Kontrollzentrum (`ipcObj.openTile(Enums.TileId.Media/Timer/...)`).
3. Der Kommentar im Kopf von `ContextZone.qml` erwähnt den Einschub „slide-in“; ein ruhiger Übergang reicht (Überblendung ist da).
4. In Settings ist `bar.contextZoneEnabled` schon als Schalter vorhanden (`config/settings-schema.json`); die Zone sollte bei „aus“ nur den Titel zeigen.

**Prüfen:** per Screenshot mit laufendem Timer (`TimerState` per Kachel starten), Medien (irgendein MPRIS-Player), Akku-Schwellen sind per Hand schwer; Text-Elide bei langen Titeln (Zone bleibt immer exakt mittig und wird nur schmaler).

## Baustein 2: „More“-Links der Dropdowns

**Stand:** `DropdownHost.qml` leitet `moreRequested(tileId)` schon als `tileRequested` weiter, und `shell.qml` öffnet damit das Kontrollzentrum (`onTileRequested: tileId => ipcObj.openTile(tileId)`). Es **senden** aber nur `BluetoothDropdown` und `NetworkDropdown` das Signal. In `AudioDropdown`, `BatteryDropdown`, `ClockDropdown` und `NightLightDropdown` steht noch ein TODO-Kommentar und kein Link.

**Zu tun:** In den vier Dropdowns unten eine ruhige Textzeile „More“ (wie in Bluetooth/Network, dort ansehen und gleich gestalten) einbauen, die `dd.moreRequested(Enums.TileId.Audio / PowerProfile / Calendar / Display)` sendet; TODO-Zeilen löschen. Tile-IDs stehen in `shell/models/Enums.qml` (`TileId`). Das Dropdown soll sich danach schließen (macht der Host schon, bei Bluetooth ansehen).

## Baustein 3: Kachel-Editor (Kontrollzentrum)

**Ziel:** In Settings → Control Center festlegen, welche Kacheln erscheinen und in welcher Reihenfolge, per Touch bedienbar.

**Stand:** Das Raster ist fest in `shell/controlcenter/ControlCenter.qml` (`property var tiles`, 6 Spalten × 5 Zeilen, jede Kachel hat `column`, `row`, `columnSpan`, `rowSpan`). Die Settings-Zeile `controlcenter.tiles` (kind `tileList`, Pfad `controlCenter.tiles`) zeigt „Edit this in settings.json for now“. Der Wert in `config/settings.json` (`controlCenter.tiles: ["calendar", "network", ...]`) ist **veraltet und wird nirgends gelesen**.

**Entscheidungen, die Lenno treffen sollte:** Soll die Reihenfolge ein freies Raster sein (Kacheln ziehen) oder eine Liste mit automatischem Umbruch? Mein Vorschlag: Liste mit Schalter „sichtbar“ und Hoch/Runter-Knöpfen (touchfreundlich, ohne Ziehen), dazu automatische Anordnung: 1×1-Schalter nach vorn, große Kacheln (Media, Calendar: 2×2) danach. Ein einfacher Packalgorithmus ersetzt die festen `column/row`-Werte. Größen bleiben pro Kachel fest (steht in `tiles`).
**Wichtig:** Die Detailansicht wächst aus dem Rechteck der Kachel (`originRect`, `DetailFrame`); sie darf von der Anordnung nicht abhängen. Der Eintrag muss durch den normalen Settings-Ablauf (Entwurf, Speichern, 15-s-Bestätigung) laufen: neue breite Editor-Zeile wie `SearchEngineEditor` (`shell/settings/`, `SettingRow.wide`), Wert als Liste von `{ id, visible }`.

## Baustein 4: Editor für Launcher-Modustasten

**Stand:** `launcher.modeKeys` (kind `keyMap`, nur „Show advanced“) ist `{ apps: "Ctrl+1", web: "Ctrl+2", settings: "Ctrl+3", ai: ..., clipboard: ... }` in `config/settings.json`; `Launcher.qml` liest es (`Shortcut`-Delegate, Zeile ~95) und `AiPanel.qml` hat feste Ctrl+1..5. Die Zeile zeigt nur den Datei-Hinweis.

**Zu tun:** Editor mit „Taste aufnehmen“: Zeile antippen, nächste Tastenkombination aufnehmen (`Keys.onPressed`, Modifier + Taste in den Qt-Text umsetzen), Konflikte zwischen den fünf Modi sofort zeigen, in den Entwurf schreiben. Danach sollte auch `AiPanel` diese Werte nutzen (heute fest). Gering priorisiert.

## Baustein 5: Web-Vorschläge in der Suche

**Stand:** Web-Modus (`Search.qml`, `case Enums.LauncherMode.Web`) liefert genau ein Ergebnis „Search the web: <Anfrage>“. Der Stub `webSuggestions` wurde im Durchgang gelöscht. `BrowserState` öffnet die Suche im Browser (Zen, `--new-tab`).

**Zu tun:** Vorschläge nachladen (z. B. DuckDuckGo `https://duckduckgo.com/ac/?q=...` oder Suchmaschinen-spezifisch, JSON), entprellt (~150 ms), in `Search.runSearch` als zusätzliche Ergebnisse mit `kind: Enums.ResultKind.WebSuggestion`. **Datenschutz:** jede getippte Zeile geht an einen Dienst; das muss ein Schalter sein (Standard aus) mit klarer Beschreibung in `config/settings-schema.json` (Kategorie Launcher). Asynchron: `runSearch` ist synchron und gibt Ergebnisse zurück; für Nachladen braucht `Launcher.qml` einen Weg, die Liste nachträglich zu ergänzen (siehe `Clipboard`-`Connections` als Muster für `refresh()`).

## Baustein 6: System-Aktionen in der Suche

**Ziel:** Im Apps-Modus Befehle wie `wifi off`, `bluetooth on`, `timer 10m`, `lock`, `night light`, `caffeine` als Ergebnis anbieten.

**Stand:** Nichts davon da (Stub `parseSystemAction` gelöscht). Ergebnisobjekte sind `SearchResult` (`shell/models/SearchResult.qml`), erzeugt über `Search.makeResult({... run: () => ... })`. Die Dienste dazu sind vorhanden: `NetworkState` (WLAN an/aus), `BluetoothState`, `TimerState` (Start mit Dauer), `CaffeineState`, `FocusState`, `NightLightState`, `LockState.lock()`, `Session` (logout/restart/shutdown).

**Zu tun:** Eine Tabelle `{ pattern, title, run }` in `Search.qml` (oder eigener Datei), `searchActions(q)` in `runSearch` für Apps vor die Programme setzen. Dienste müssen in `Search` bekannt sein (wie `browser`/`settingsState` aus `shell.qml` zugewiesen). Zeitangaben („10m“, „1h30“) sauber parsen und Fehlformen ignorieren.

## Baustein 7: Login-Hintergrund aus dem Picker

**Stand:** Der Greeter liest `wallpaper` aus `/etc/aptus/greeter.json`; der Pfad muss für den Benutzer `greetd` lesbar sein (nicht unter `/home`). Der Wallpaper-Picker (`shell/wallpaper/WallpaperPicker.qml`) setzt nur das Sitzungsbild (`~/.local/state/aptus/wallpaper`).

**Zu tun:** Im Picker ein Knopf „Use for login screen“. Braucht root: Kopie nach `/usr/local/share/aptus/wallpaper.jpg` und Eintrag in `/etc/aptus/greeter.json`. Weg ohne Passwortabfrage im Shell-Prozess: `pkexec` mit einem kleinen Hilfsskript `bin/aptus-greeter-wallpaper` (Polkit fragt grafisch; Skript prüft Dateityp und Größe, kopiert, schreibt das JSON). Alternativ nur dokumentieren. Greeter lädt das Bild schon (`GreeterSurface.qml`, Image + Schleier).

## Baustein 8: Installer fertigstellen

**Stand:** `install.sh` kann `link_config`, `install_launcher`, `patch_shell_switch`, `install_hyprland_binds`, `ensure_cliphist` (prüft nur), `check_lid_policy` (prüft nur), `install_greeter`/`uninstall_greeter` (`--greeter`, `--uninstall-greeter`). Noch Platzhalter (`not_implemented`): `enable_repos` und `install_packages`; `main` ruft sie nicht auf.

**Zu tun:** `install_packages` mit `dnf`: Quickshell ≥ 0.3.2 (Lennos Rechner hat es aus dem COPR `lionheartp/Hyprland`), `hyprsunset`, `brightnessctl`, `playerctl`, `grim`, `slurp`, `wl-clipboard`, `cliphist`, `iio-sensor-proxy`, `cage` (Greeter), `hypridle` optional, `python3`. Jede Systemänderung vorher zeigen und nachfragen (Regel des Projekts), `--dry-run` und `--yes` beachten. `enable_repos` nur nach Nachfrage und mit dem COPR-Namen. Es gibt keinen Weg zurück-Teil für Pakete (nur Hinweis). Am Ende `uninstall` für die Konfiguration (Links entfernen, `.before-aptus` zurückspielen) ist ebenfalls offen und im README noch nicht erwähnt.

## Baustein 9: AI-Nutzung Variante B (nur mit Lennos Okay)

**Stand:** `shell/services/AiUsageState.qml` liest `~/.claude/usage-cache.json` (5-h- und 7-Tage-Fenster, Aufteilung nach Produkt, Alter der Daten). aptus fasst kein Token an. Die Datei pflegt das Noctalia-Plugin „claudecode“ bzw. Claude Code; wenn Noctalia nicht läuft, kann sie veralten (Kachel zeigt „old“ ab 30 min). **Nicht geklärt:** schreibt Claude Code selbst diese Datei? Lenno soll beobachten, ob „Updated vor x min“ wächst.

**Variante B (nur nach ausdrücklichem Okay):** frische Zahlen direkt von `https://api.anthropic.com/api/oauth/usage` (Header `Authorization: Bearer <accessToken>` aus `~/.claude/.credentials.json`, `anthropic-beta: oauth-2025-04-20`), alle paar Minuten, Token nie loggen, hinter einem Schalter (Standard aus) mit klarer Beschreibung. Das Plugin-Skript `~/.local/state/noctalia/plugins/materialized/community/claudecode/get-claude-usage` zeigt, wie Token-Erneuerung läuft (nicht nachbauen, wenn es vermeidbar ist). Für `agy` und `vibe` gibt es keine Zahlen.

## Kleinere offene Punkte

- **Einschränkung der Werkzeuge** für kurze AI-Fragen: `claude` läuft mit `--tools ""`, bei `agy` und `vibe` (Mistral) ist offen, wie man Werkzeuge abschaltet (`vibe --enabled-tools ...`); die Argumente stehen in `config/ai-providers.json`, `verified: false`. Vor Änderung `agy --help` und `vibe --help` lesen.
- **Zahlen mit festen Ziffern:** `Label.qml` hat `tabularNumbers`, das TODO dort verlangt einen Test, ob Qt 6.11 die OpenType-Eigenschaft `tnum` für Inter wirklich anwendet.
- **Nachtlicht-Übergang:** `Tokens.applyPalette` soll sich über Minuten weich bewegen (TODO in `Tokens.qml`); `NightLightState` macht schon einen 4-s-Übergang, Lennos Wunsch war „nie ein Blitz“.
- **Hintergrund-Unschärfe:** Der Regler „Background blur“ setzt jetzt die Hyprland-Unschärfe (`size = Wert/2`). Lennos gespeicherter Wert ist 6 (Standard 18), deshalb ist sie schwächer als vorher; bei Gefallen Standardwert und Zuordnung prüfen.
- **Greeter:** läuft (Lenno: „works“). Ungetestet: Touch-Tastatur dort, Restart/Shut down aus dem Greeter (Rechte des Benutzers `greetd` für `systemctl reboot`), Drehung. Log: `/var/cache/aptus-greeter/greeter.log`. Notweg: Strg+Alt+F3, `sudo cp /etc/greetd/config.toml.before-aptus /etc/greetd/config.toml && sudo systemctl restart greetd`.
- **Nur am Gerät prüfbar:** Touch-Wischen von oben/links, Tablet-Modus (der HP-WMI-Schalter meldet bei diesem Gerät nie, zweimal 60 s gemessen; Lenno nutzt den Tablet-Knopf im Kontrollzentrum, IPC `tabletToggle`), Drehrichtungen (`DeviceModeState`: normal=0, left-up=1, bottom-up=2, right-up=3, evtl. vertauscht), Klicks in den Settings, Idle-Sperre nach 5 min, Bildschirm-Aus nach 10 min, Deckel zu, Warnfarben der AI-Kachel (ab 70 % amber, ab 90 % rot).
- **Repo:** `README.md` und MIT-`LICENSE` sind da. Der Punkt im Namen bleibt (Repo heißt `aptus.`), technischer Name `aptus`. Kein Screenshot in der README (wäre ein guter Abschluss).

## Wichtige Dateien (Orientierung)

- Einstieg und Verdrahtung: `shell/shell.qml`, IPC: `shell/IpcHandlers.qml`, Zustand: `shell/models/*State.qml`, Dienste: `shell/services/`.
- Leiste: `shell/bar/`, Dropdowns: `shell/dropdowns/`, Kontrollzentrum: `shell/controlcenter/` (+ `tiles/`), Launcher: `shell/launcher/`, Settings: `shell/settings/` (Zeilen-Editoren dort, Schema in `config/settings-schema.json`, Standardwerte `config/settings.json`, Nutzerdatei `~/.config/aptus/settings.json`), Sperre: `shell/lock/`, Greeter: `greeter/` + `bin/aptus-greeter-build`, Tastatur: `shell/osk/` + `shell/services/Osk.qml`, Hintergrund: `shell/wallpaper/`, Power-Menü: `shell/session/`, Touch: `shell/touch/`.
- Skripte: `bin/aptus` (Start und `msg`), `bin/aptus-settings-watchdog`, `bin/aptus-patch-shell-switch`, `bin/aptus-greeter-session`, `bin/aptus-greeter-build`, `install.sh`.
