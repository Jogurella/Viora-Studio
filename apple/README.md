# Viora Studio für Apple

Native SwiftUI-App für iPhone (iOS 17+) und Mac (macOS 14+). Gemeinsamer Foundation-Client, getrennte Views/ViewModel, keine WebView, keine Fremdpakete und keine Modellgewichte. Design gemäß iPhone-Vorlage v2, Space Grotesk / Manrope / JetBrains Mono mit beigefügten SIL-OFL-Lizenzen, eigener gezeichneter App-Icon. Tastatur über den Knopf neben Prompt oder die Tastaturleiste ausblenden; Scrollen kann sie ebenfalls schließen.

## Bauen

Xcode 26.3 wurde geprüft. `VioraStudio.xcodeproj` öffnen und Scheme `VioraStudio` wählen. Für ein Gerät unter Signing das eigene Team auswählen. Die Bundle-ID lautet `com.jogurella.viorastudio`; Team und Zertifikate sind nicht im Projekt hinterlegt.

```sh
swift test --package-path apple
xcodebuild -project apple/VioraStudio.xcodeproj -scheme VioraStudio -destination 'platform=macOS' CODE_SIGN_IDENTITY=- build
xcodebuild -project apple/VioraStudio.xcodeproj -scheme VioraStudio -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

`-derivedDataPath /Pfad/auf/APFS` hält Build-Daten auf dem gewünschten Laufwerk. Auf ExFAT ein APFS-Disk-Image für Build-Produkte verwenden: AppleDouble-Dateien können App-Signaturen stören. `python3 apple/scripts/generate-project.py` regeneriert das eingecheckte Projekt nach Änderungen an der Dateiliste und ignoriert AppleDouble-Dateien.

## Benutzen

1. Tailscale verbinden. In Einstellungen die private HTTPS-Adresse samt Port eingeben und „Verbinden & Modelle laden“ wählen. Die letzte erfolgreiche Kopplung wird beim App-Start wiederhergestellt; Status und Fehler erscheinen direkt im Kopplungsfenster.
2. Am Mac einen lokalen Galerieordner wählen oder anlegen. Auf dem iPhone wird die interne App-Galerie verwendet.
3. Modell, Prompt, einen von 22 editierbaren Stilen und Format wählen. Beim Wechsel auf Video wird das gewählte bzw. letzte generierte Bild übernommen. Video-Einstellungen bleiben inline: Modellpaar, Länge 1–60 Sekunden, Bildrate 8–120 FPS (nach Servergrenzen), Qualität und weitere Parameter. Eine FPS-Änderung erhält die gewählte Dauer. Längere Videos verwenden die serverseitige Fortsetzung in Wan-Fenstern mit höchstens 81 Frames und einem gemeinsamen Übergangsframe; sichtbare Übergänge und lange Laufzeiten sind möglich. Es wird keine installierte Frame-Interpolation vorausgesetzt.
4. Fortschritt stammt aus SwarmUI. „Lokal gespeichert“ erscheint erst nach erfolgreichem Download und Metadatenspeicherung.
5. Ergebnisse über Galerie öffnen, favorisieren, teilen/exportieren oder als Ausgangsbild animieren. Fotos-Speicherung nur auf ausdrückliche Aktion.

Die Queue ist die echte lokale Client-Queue; Serverzahlen sind gesondert als letzter Serverstatus ausgewiesen. Einträge lassen sich aus der Queue löschen; bei aktiven Aufträgen wird vorher der sitzungsbezogene Serverabbruch bestätigt. Medien bleiben in der Galerie. Bei Abbruch/Fehler pausiert die Queue. Bei Verbindungsverlust und nach Neustart werden alte Aufträge niemals automatisch erneut gesendet. Ein abgebrochener Job kann auf dem Server noch laufen, bis InterruptAll und dessen Sitzungsstatus bestätigt sind. App während einer Generierung im Vordergrund lassen; es gibt keinen zugesicherten iOS-Hintergrundbetrieb.

## Speicher und Updates

UserDefaults speichert Serveradresse und macOS-Bookmark. `Application Support/VioraStudio` enthält das private Queue-Journal (inklusive Sitzungs-ID zur gezielten Abbruchprüfung). Medien und ihre individuellen `viora-UUID.json`-Metadaten liegen im gewählten Ordner bzw. der iPhone-App-Galerie. Ein Download wird erst über eine temporäre Datei fertiggestellt; vorhandene Dateien werden nicht überschrieben. Ein Ordnerwechsel kopiert keine bestehenden Medien.

Die Daten liegen außerhalb des App-Bundles. Updates mit gleicher Bundle-ID und Signierungsidentität erhalten sie. App-Löschen kann die iPhone-Galerie entfernen; vorher exportieren. Keine automatische Datenmigration aus der Windows-Galerie: deren Sidecar-Format ist eigenständig.

Release-/SideStore-Vorbereitung: `../docs/apple-releases.md`. Tatsächliche Prüfungen und Grenzen: `../docs/status/apple.md`.

## Live-Prüfung

`LiveSmoke.swift` nutzt denselben Client und dieselbe Galerie wie die App. Ein Aufruf erzeugt wirklich einen Job. Private URL ausschließlich als lokales Argument übergeben; Ergebnisordner außerhalb des Git-Repositories wählen.

```sh
swiftc -parse-as-library apple/Sources/VioraCore/*.swift apple/scripts/LiveSmoke.swift -o /lokaler/pfad/LiveSmoke
/lokaler/pfad/LiveSmoke 'https://DEIN-SERVER/' /lokaler/testordner
# Optionales viertes Argument: lokaler Pfad des Ausgangsbilds für einen kurzen Video-Test.
```

## Persönlicher Build

Optional `VIORA_DEFAULT_SERVER_URL` beim lokalen xcodebuild-Aufruf setzen. Der Wert wird nur in dessen App-Bundle eingebaut; der öffentliche Projektstandard bleibt leer. Die App ergänzt bei einem exakt passenden bekannten Servernamen die konfigurierte HTTPS-Adresse samt Port. Persönliche IPA/macOS-Pakete mit voreingestellter Privatadresse nicht als öffentliche Release-Artefakte verwenden.

Die Animationen umfassen Hintergrundbewegung, gestaffeltes Einblenden, gleitende Modus-/Tab-Markierung, Vorschau-Puls und Lichtreflex; „Bewegung reduzieren“ wird berücksichtigt. Unter iOS stehen Generieren und Navigation in einem eigenen unteren Bereich, der Scrollinhalt wird darüber abgeschnitten.

Die Videofortsetzung folgt der [SwarmUI-Dokumentation](https://github.com/mcmonkeyprojects/SwarmUI/blob/fcc435dd7ac9da96f0db4c61f5de61bc2b268f26/docs/Features/Prompt%20Syntax.md#video-extend). Längere/höher aufgelöste Ausgaben sind kein zugesicherter Leistungswert. Der Live-Smoke-Test akzeptiert nach dem Bildpfad optional Sekunden, FPS und Test-Schritte.
