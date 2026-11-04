# Apple-Ergänzung zum gemeinsamen Clientvertrag v1

Basis: `swarm-v1.md`. Tatsächlich abgeglichen mit SwarmUI `0.9.8.4.GIT-fcc435dd`, am 04.11.2026. Vollständiger Upstream-Commit: `fcc435dd7ac9da96f0db4c61f5de61bc2b268f26`.

Apple akzeptiert ausschließlich HTTPS/WSS, auch bei lokaler Konfiguration. Scheme-Namen werden ohne Beachtung der Großschreibung normalisiert. Sitzungs-/Modell-/Parameterfehler verhindern den Generierungsstart. `ListT2IParams` meldet verfügbare Parameter, Zahlenbereiche und Sampler/Scheduler. Die Modellliste wird ausschließlich aus `ListModels.files` gebildet. Stilpresets ergänzen editierbare Prompttexte.

WebSocket-Formate werden explizit ausgewertet:

- `status`: Sitzungszähler, kein daraus abgeleiteter Fortschrittswert.
- `gen_progress`: `overall_percent` / `current_percent` als Bruchteil 0…1, `batch_index`, optionaler Data-URL-Preview. Ungültige/fehlende Werte werden nicht durch Schätzungen ersetzt.
- Ergebnis: aktuell `{ "image": "View/...", "batch_index": "0", "metadata": "..." }`; zusätzlich wird das verschachtelte Beispiel aus der API-Dokumentation erkannt.
- `discard_indices`: entfernt die genannten Batch-Ergebnisse vor dem Download.
- `socket_intention: "close"`: bestätigter Abschluss. Ein Verbindungsende ohne dieses Signal gilt in diesem gepinnten Vertrag als unklar und löst keinen erneuten Auftrag aus.
- `error` oder `error_id`: verständlicher Fehler, Queue pausiert. Insbesondere kein automatischer Generation-Retry bei `invalid_session_id`.

Jeder aktive Clientjob erhält eine neue Sitzung. InterruptAll sendet ausdrücklich `other_sessions:false`. Anschließend wird GetCurrentStatus für dieselbe Sitzung bis zu 15-mal geprüft; erst wenn alle vier Sitzungszähler 0 sind, gilt der Serverabbruch als bestätigt. Ein Timeout bleibt als unklar sichtbar.

Video nutzt den nativen I2V-Vertrag mit `videomodel`, `videoswapmodel`, `videoswappercent:0.5`, `initimage`, `initimagecreativity:0`, `videoframes`, `videofps:16`, `videosteps`, `videocfg`, `videoresolution:"Image"`, `videoformat:"h264-mp4"`. Kein Custom-Workflow-String; `${init_image}` muss daher nicht substituiert werden. Die App erlaubt 9…81 Frames in Schritten von 4, Standard 49, und Videoformate mit 32-Pixel-Raster (bis 512 Pixel pro Seite). Ein Video-Ausgangsbild ist erforderlich. Bildformate und Schrittanzahl dürfen zwischen den Clients variieren.

Download-URLs und Redirects bleiben auf derselben HTTPS-Origin (Host/Port/Scheme). URLSession streamt Dateien auf Disk. Data-URL-Ergebnisse sind auf 32 MiB begrenzt. Die Galerie prüft Mediensignaturen, verwendet UUID-Dateinamen, schreibt zunächst eine versteckte Download-Datei und verschiebt sie atomar zum Ziel. Ein JSON-Sidecar folgt atomar; schlägt dies fehl, wird die neu erzeugte Mediendatei zurückgenommen. Ein abgebrochener Download erscheint nicht als fertiger Galerieeintrag. Servermetadaten liefern den tatsächlichen Seed; fehlt er bei Zufallsseed, steht dort „Vom Server nicht gemeldet“.

Protokollquellen:
- https://github.com/mcmonkeyprojects/SwarmUI/blob/fcc435dd7ac9da96f0db4c61f5de61bc2b268f26/src/WebAPI/T2IAPI.cs
- https://github.com/mcmonkeyprojects/SwarmUI/blob/fcc435dd7ac9da96f0db4c61f5de61bc2b268f26/src/Text2Image/T2IParamTypes.cs
- https://github.com/mcmonkeyprojects/SwarmUI/blob/fcc435dd7ac9da96f0db4c61f5de61bc2b268f26/docs/Video%20Model%20Support.md
