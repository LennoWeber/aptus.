# shell. (aptus): Arbeitsregeln für Claude

Desktop-Shell für Fedora + Hyprland (Quickshell 0.3.2, QML), gebaut für Lenno (HP ENVY x360 15-ey0xxx, 1920x1080, 2-in-1 mit Touch). Es ist ein UI-/System-Design-Projekt: Aussehen und Gefühl sind fast wichtiger als die Sache selbst.

## Zuerst lesen
`PHASES.md` ist der Stand des Projekts: Ziel, Entscheidungen, abgeschlossene Abschnitte, offene Punkte, nächster Schritt. Vor jeder Arbeit lesen, danach aktuell halten.

## Arbeitsweise
- Auf Deutsch antworten, knapp. Berichte enden mit „sage weiter“.
- Vorgehen nach dem Skill `phasen-entwicklung`. Wir sind in **Phase 7 (Implementierung)**, die in Abschnitten geliefert wird. Nach jedem Abschnitt anhalten und auf „weiter“ warten; Lenno testet auf dem Laptop. Kein Sub-Agent, außer Lenno verlangt ihn ausdrücklich.
- Lennos Anweisungen genau befolgen und herausfinden, was er wirklich will. Eigene Ideen entwickeln und sich nicht an anderen Shell-Projekten orientieren.
- Auf dem Laptop selbst testen, wenn möglich: Shell starten, `qs log -p <ordner>/shell` lesen, Screenshot mit `grim` prüfen. Bei Unsicherheit lieber ausprobieren als raten.

## Namen
- Technisch/Repo: `aptus` (Binary `aptus`, Konfig `~/.config/quickshell/aptus`, IPC-Ziel `aptus`, Layer-Namespaces `aptus-*`, Zustand `~/.local/state/aptus`).
- Sichtbare Marke nur **„shell.“** (Inter, semibold) oben links in der Leiste.

## Gestaltung (Kurzfassung, Details in PHASES.md)
- Leiste 28 px, deckend; helle Oberfläche mit weichem Nachtlicht-Übergang; englische UI.
- Farbe nur als Signal: grün = aktiv/ok, amber = Achtung/kostet etwas, rot = stumm/Aufnahme/kritisch; nur auf kleinen Elementen, immer mit Text oder Form dazu.
- Kein Glas/Transparenz auf Leiste und Dropdowns; Unschärfe nur hinter Kontrollzentrum und Launcher.
- Drei Stufen: Dropdown, Kontrollzentrum, Kachel-Detail; Esc geht eine Stufe zurück.
- Rückmeldung sofort (<= 50 ms), Animationen 140/260 ms, eine Kurve [0.2, 0, 0, 1].
- Nie Suspend/Hibernate.

## Technik
- Lint: `./aptus-lint.sh` (qmllint, schreibt `aptus-lint.txt`), Ziel 0 Warnungen.
- QML: `pragma ComponentBehavior: Bound` bei verschachtelten Komponenten; kein `signal` als Eigenschaftsname; Enum-Namen dürfen nicht mit Werten eines anderen Enums im selben Typ kollidieren (so entstand der Power-Profil-Fehler).
- Hyprland-Konfiguration ist Lua (`hl.config`, `hl.bind`), Lennos Binds senden `shell-switch msg <befehl>`.
- Installer verlinkt in den entpackten Ordner; nach Änderungen an Dateien reicht ein Neustart der Shell (`pkill -f "qs -p"` und `shell-switch to aptus`).
