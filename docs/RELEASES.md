# Releases erstellen

Windows-Version in `src/SwarmStudio.csproj` ändern. Build und Selftests aus README ausführen. Reale Bild-/Video- und Oberflächenprüfung bei Änderungen an Generierung durchführen.

Eine selbständige Windows-x64-EXE mit dem dokumentierten Publish-Befehl erstellen. ZIP anlegen mit `VioraStudio.exe` und `ANLEITUNG.txt` direkt an der Wurzel. Name: `VioraStudio-win-x64.zip`. SHA-256 der fertigen ZIP berechnen und als `HASH  VioraStudio-win-x64.zip` in `SHA256SUMS.txt` speichern.

Auf GitHub einen Release mit passendem Tag `vMAJOR.MINOR.PATCH` vorbereiten, beide Dateien anhängen, Notizen und Plattformstatus prüfen, dann veröffentlichen. Die CI prüft Builds und Paketvalidierung; sie veröffentlicht selbst keine Releases.

Apple-Artefakte erst ergänzen, wenn gebaut und signiert. Gemeinsame Version ist das Ziel; fehlende Plattform-Builds transparent als offen kennzeichnen. Öffentliches Windows-Update enthält niemals persönliche Einstellungen, Serveradresse, Queue oder Galerie.

Windows-Updater prüft das neueste stabile Release, Versionsnummer und SHA-256. Installation erfolgt durch manuellen Austausch der EXE nach dem Schließen. Ein selbst austauschender Updatehelfer ist in v1 nicht enthalten.
