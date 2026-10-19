# Test Abschnitt 4a
1. Kontrollzentrum öffnen: 6 Spalten, alle Kacheln sichtbar, nichts abgeschnitten (auch bei der Höhe 1080).
2. Focus und Caffeine: Tippen schaltet um (grün = an).
3. Timer: Play-Knopf in der Kachel startet 5 min; Kachel öffnen, Presets und Pomodoro probieren.
4. Weather: zeigt Berlin (config/settings.json), Detail mit Stunden und Tagen.
5. System: Balken laufen nur bei offenem Kontrollzentrum; Detail mit Kernen, RAM, Disk, Netz.
6. Capture: Region-Screenshot (Kontrollzentrum schließt sich, dann Auswahl); Aufnahme starten und stoppen. Fehlt ein Programm, steht es in der Ansicht.
7. VPN: Liste der NetworkManager-Profile; Hotspot NUR mit Ethernet ausprobieren (sonst verlierst du das WLAN).
8. Power: Profilkarten anklicken. Falls es nicht klappt: `qs log -p <ordner>/shell` und die Meldung schicken.
9. `./aptus-lint.sh` laufen lassen und die Ausgabe schicken.
