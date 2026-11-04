# Apple-Status – 04.11.2026

Version: 0.1.0, Build 3 auf `codex/apple`. Basis des gemeinsamen Repositories `71e3784`; erster Apple-Stand `face879`, anschließend die unten beschriebenen Nutzerkorrekturen.

Xcode/SDK/Zielsysteme: Xcode 26.3 (17C529), Apple Swift 6.2.4; iPhoneOS/iPhoneSimulator SDK 26.2, macOS SDK 26.2. Deployment iOS 17 / macOS 14. Apple Silicon lokal geprüft. Keine externen Laufzeitpakete.

Server-API-Version: SwarmUI `0.9.8.4.GIT-fcc435dd`, live abgeglichen; GetNewSession, ListModels, ListT2IParams, GetCurrentStatus erfolgreich. SDXL Base und Wan 2.2 I2V HighNoise/LowNoise Q4 wurden live geprüft; bei der letzten Kopplung meldete der Server vier Modelle. Der öffentliche Quellcode enthält keine Privatadresse. Der persönliche lokale Build erhält seinen Server über `VIORA_DEFAULT_SERVER_URL`.

## Builds und Tests

- macOS Debug und Release erfolgreich gebaut; Bundle-Signatur mit `codesign --verify --deep --strict` geprüft. Ad-hoc-Signatur für lokalen Start, keine Notarisierung.
- iPhone-Simulator erfolgreich gebaut und gestartet. Native Oberfläche gegen die neue verbindliche iPhone-Vorlage v2 bei **390×844** Punkten visuell geprüft. Kompakte Erstellen-Ansicht, Format-Chips, Modell/Anzahl/Optionen, schwebende Navigation und gebündelte OFL-Schriften. macOS übernimmt dieselben Komponenten in einer Mehrspaltenansicht.
- Bildschirmtastatur im Simulator eingeblendet, Prompt eingegeben und mit dem neuen Knopf geschlossen. Tab-Navigation erscheint danach wieder. Zusätzlich Tastaturleiste und interaktives Schließen beim Scrollen.
- iOS Release-Archiv und IPA-Export erfolgreich. Echte signierte Build-3-IPA auf gepaartem iPhone 17 Pro installiert und per devicectl gestartet. Anfängliche Installation am Limit der drei kostenlosen Apps gescheitert; nach Nutzeränderung erfolgreich. Keine bestehenden Apps durch diese Umsetzung gelöscht.
- Acht Swift/XCTest-Prüfungen bestanden: HTTPS/Same-Origin/URL-Normalisierung, flache/verschachtelte Ergebnisse und Seed, ungültiger Fortschritt und Serverfehler, Completion/Discard, Modell-/Video-Payload-Validierung sowie Galerie-Commit/Favorit/Neuladen/ungültige Downloads.
- Echter Bildtest über denselben Swift-Client: SDXL 512×512, 10 Schritte, Ergebnis heruntergeladen, Galerie neu eingelesen, Bild visuell geöffnet. Dauer ca. 3,7 s unter den konkreten Testbedingungen, keine Geschwindigkeitszusage.
- Echter Video-Test: Ausgangsbild → natives Wan HighNoise/LowNoise, 512×320, 9 Frames, 16 FPS, 10 Schritte. MP4 nach ca. 82 s heruntergeladen. Mit AVFoundation verifiziert: Video-Track, 512×320, 0,563 s, erstes Bild dekodierbar. Längere 49-/81-Frame-Ausgaben wurden nicht erneut belastungsgetestet.
- macOS-UI: Server verbinden, reale Modelle, echte Generierung, Download in gewählten SSD-Galerieordner, Ergebnis öffnen, Favorit setzen, App beenden/neustarten. Galerie und Favorit samt security-scoped Ordnerzugriff erhalten.
- iPhone-Simulator: echte Serververbindung, Modellauswahl und Bildgenerierung mit lokalem Ergebnis. Dieser End-to-End-Test erfolgte vor dem reinen UI-Ersatz; die verwendeten Generierungs-/Galerieservices sind weiterhin dieselben.
- Abbruch: eigener realer SDXL-Testauftrag, echter Fortschritt empfangen, InterruptAll mit other_sessions=false; Sitzungsstatus danach vollständig idle. Kein erneuter Job gesendet.
- Offline: UI-Test mit nicht auflösbarem Testhost zeigt die verständliche Tailscale-/Erreichbarkeitsmeldung. Ungültige URL wurde ebenfalls abgefangen. TLS-Validierung bleibt unverändert aktiv; keine Zertifikatsausnahmen.

## Nutzerkorrekturen in Build 3

- Kopplungsfehler auf dem physischen iPhone eingegrenzt: Der gespeicherte reine Hostname enthielt weder HTTPS noch den erforderlichen Port. Passende lokale Voreinstellung ergänzt beides; die letzte erfolgreiche Adresse wird automatisch wieder verbunden. Fehler bleiben inline sichtbar. Auf dem realen iPhone nach Installation/Start bestätigt: frischer erfolgreicher API-Kontakt und vier geladene Modelle.
- Bewegter Hintergrund, gestaffelte Einblendung, gleitende Bild/Video- und Tab-Auswahl, Vorschau-Puls, Button-Lichtreflex und Druckeffekt. Systemeinstellung für reduzierte Bewegung berücksichtigt.
- Fester unterer Bereich für Generieren und Navigation, vom Scrollinhalt getrennt. Tastaturknopf im Simulator erneut betätigt und Schließen bestätigt.
- Video-Optionen direkt im Erstellen-Bildschirm; automatische Übernahme des letzten/gewählten generierten Bilds, Inline-Galerieauswahl und Bildimport. Mit einem zuvor tatsächlich generierten und in die Simulatorgalerie kopierten Testbild geprüft. Inline-Umschaltung und Auswahl 10 Sekunden/60 FPS ergeben 601 Frames bzw. 10,02 Sekunden; kein Settings-Sheet.
- 22 Stile für Bild und Video. Dauerwahl 1–60 s und FPS 8/16/24/25/30/48/50/60/120 gemäß Servergrenzen. Höhere FPS erhalten die gewünschte Dauer durch zusätzliche Frames, ohne vorzugeben, dass Frame-Interpolation installiert ist.
- Lange Clips werden über den nativen `<extend:…>`-Pfad des geprüften SwarmUI-Commits gebaut. Tests prüfen 63 Kombinationen aus Dauer/FPS, maximal 81 Frames je Abschnitt, 4n+1, korrekte Gesamtframezahl nach Überlappung, Payload und fehlende Serverfunktionen. Rundungsabweichung bis drei Frames ist ausgewiesen.
- Queue-Löschen vorhanden. Eigener wartender Serverauftrag über den aktiven Löschen-Knopf gestoppt, serverseitiges Idle bestätigt, Eintrag anschließend entfernt. Fremde Sitzungen wurden nicht unterbrochen. Eigene Sitzungsstatus werden während der Generierung nachgeladen, einschließlich „Wartet auf freien Server“.
- Zusätzlicher Live-Test für 6 s/30 FPS/181 Frames wurde gesendet. Der Server meldete einen anderen aktiven Auftrag und wartende Backendzugriffe; dieser Test kam nicht zur Ausführung. Eigene Testsitzung gezielt beendet und Idle bestätigt. Lange Ausgabe und hohe tatsächliche MP4-Bildrate bleiben daher **nicht live abgenommen**.

## Speicher und Auslieferung

macOS-Galerie: frei wählbarer Ordner, Security-Scoped-Bookmark; Fotos/Dateienexport auf iOS implementiert. Persistenz nach normalem Neustart geprüft. Ein vollständiger Update-/Neuinstallations-Migrationstest, verweigerte Fotosberechtigung, volles Laufwerk und physisch abgezogene SSD wurden nicht simuliert. Fehler werden im Code abgefangen und nicht als Erfolg angezeigt.

iOS-Signierung: echtes Apple-Development-Profil, gültig bis **11.11.2026, 00:17 UTC**. Persönliche Team-/Gerätekennung und Profil bleiben lokal. macOS: lokal ausführbar, öffentlich verteilbare Developer-ID-/Notarisierung noch offen.

GitHub-Release/SideStore-Feed/Sparkle: Quellcode und Build-CI vorbereitet. Lokale IPA und macOS-ZIP sind reale Artefakte, mit SHA-256. Bestehendes Windows-v0.1.0-Release nicht verändert. Kein öffentlicher Apple-Release und kein aktiver Feed. `updates/make-apple-source.py` prüft signierte IPA, Profilablauf und Bytegleichheit der erreichbaren Release-Datei vor der Feed-Erzeugung; lokaler Inspect-Modus erfolgreich. SideStore-Import/Erneuerung und Sparkle-Update sind noch nicht abgenommen. Das persönliche Geräteprofil wird nicht ungefragt öffentlich hochgeladen.

Offen: Generierung auf dem physischen iPhone (Installation/Start sind belegt), reale Foto-/Dateienexportaktionen, längere Videoclips, Update-/Abzieh-/Vollspeichertests, öffentlicher Signierungs- und Updateweg. Hintergrundgenerierung unter iOS wird nicht zugesichert.

## Reproduzierbare Befehle

```sh
swift test --package-path apple --scratch-path /APFS/SwiftPackage
xcodebuild -project apple/VioraStudio.xcodeproj -scheme VioraStudio -configuration Release -destination 'platform=macOS' -derivedDataPath /APFS/macOS CODE_SIGN_IDENTITY=- build
xcodebuild -project apple/VioraStudio.xcodeproj -scheme VioraStudio -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /APFS/iOS-Simulator CODE_SIGNING_ALLOWED=NO build
xcodebuild -project apple/VioraStudio.xcodeproj -scheme VioraStudio -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /APFS/iOS-Device -archivePath /APFS/VioraStudio-iOS.xcarchive DEVELOPMENT_TEAM=DEINTEAM -allowProvisioningUpdates archive
```

Export mit privater ExportOptions.plist (`method: debugging`, eigenes Team). Auf ExFAT ein APFS-Disk-Image für signierte Produkte nutzen. Ein schon vorhandenes Xcode-Datenlaufwerk musste vor Simulator-/Signing-Tests wieder eingehängt werden; dessen Dateien wurden nicht verschoben.
