# Gemeinsamer Clientvertrag v1

Referenzserver: SwarmUI 0.9.8.4, Commit fcc435dd. Implementierung in `src/SwarmClient.cs`. Apple-Clients sollen dieselben Abläufe verwenden und Änderungen am Vertrag gemeinsam versionieren.

## Verbindung

Benutzerkonfigurierbare HTTPS-Root-URL mit optionalem Port. Keine Benutzerinformationen oder privaten Adressen im öffentlichen Quelltext. HTTP nur für Loopback zulassen. Keine TLS-Ausnahmen. Tailscale stellt privaten Fernzugriff bereit; kein öffentliches Funnel nötig.

1. POST `/API/GetNewSession` mit `{}`. `session_id` nur in der Sitzung halten.
2. POST `/API/ListModels` mit `session_id`, `path:""`, `depth:10`, `subtype:"Stable-Diffusion"`. `files` auswerten. Windows v1 unterstützt SDXL und Wan2.2-I2V-HighNoise mit passendem LowNoise-Partner.
3. WSS `/API/GenerateText2ImageWS`. Einen JSON-Auftrag mit `session_id` senden.
4. Fortschritt über `gen_progress.overall_percent` (0..1), optionale Vorschau über `gen_progress.preview`, Ladezustand über `status.loading_models`. Keine geschätzten Prozentzahlen.
5. Ergebnisse: `image`-URL anhand `batch_index` sammeln. `discard_indices` entfernt genau diese Batch-Indizes. Auf `socket_intention:"close"` oder WebSocket-Ende abschließen; Fehlernachrichten anzeigen.
6. Relative `View/...`-URLs vom eigenen Server herunterladen. Fremde absolute URLs ablehnen. Nicht ohne Nachfrage nach Verbindungsverlust nochmals generieren.
7. POST `/API/InterruptAll` mit `session_id`, `other_sessions:false`. Eigene Sitzung pro aktivem Auftrag. Beim Abbruch Queue pausieren, damit der nächste Job nicht sofort startet.

## Bild

`images`, `model`, `prompt`, `negativeprompt`, `width`, `height`, `steps`, `cfgscale`, `seed`, `sampler:"euler"`, `scheduler:"normal"`.

v1-Formate: 768×768, 576×1024, 1024×576. Qualität: 12/25/35 Schritte, CFG 7. Stile sind nachvollziehbare Promptzusätze.

## Video

Optional ein Startbild. Ohne Upload zunächst ein einzelnes SDXL-Bild erzeugen. Anschließend natives SwarmUI I2V:

`images:1`, `model:<SDXL>`, `initimage:<PNG-data-URL>`, `initimagecreativity:0`, `videomodel:<HighNoise>`, `videoswapmodel:<LowNoise>`, `videoswappercent:0.5`, `videoframes:25|49|81`, `videosteps:12|20|30`, `videocfg:3.5`, `videofps:16`, `videoformat:"h264-mp4"`, `videoresolution:"Image"`, `sigmashift:5`, `vaetilesize:256`, `vaetemporaltilesize:16`, `vaetemporaltileoverlap:4`, Prompt/Negativprompt/Seed/Abmessungen.

v1-Videoformate: 512×512, 288×512, 512×288. Wenige VRAM-Ressourcen begrenzen Qualität/Geschwindigkeit. Mehr Auflösung benötigt gesonderte Prüfung. Der kurze 256×256-Funktionstest ist kein Qualitätsnachweis für längere Clips.

## Lokale Speicherung

Client lädt Daten vollständig herunter, schreibt `.part`, benennt danach atomar um und schreibt JSON-Metadaten. Windows: frei wählbarer Galerieordner, Medien plus `.swarm.json`. macOS: Ordner mit security-scoped Bookmark. iOS: interne Galerie plus ausdrücklicher Fotos-/Dateienexport. Metadaten/Medien nicht öffentlich synchronisieren.

## Updates

Gemeinsames Repository Jogurella/Viora-Studio. Stabile Tags `vMAJOR.MINOR.PATCH`. Windows-Assets `VioraStudio-win-x64.zip` und `SHA256SUMS.txt`; ZIP enthält `VioraStudio.exe` an der Wurzel. SHA-256 schützt vor beschädigtem Download, ersetzt keine Herausgebersignatur. Windows lädt und prüft, der Nutzer ersetzt anschließend die EXE. Apple-Feeds erst nach realem signiertem Build veröffentlichen.
