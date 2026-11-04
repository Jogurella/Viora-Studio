# Viora Studio

Native Windows-App für Bilder und kurze KI-Videos über einen eigenen SwarmUI-Server. Ergebnisse werden auf dem jeweiligen PC in einen frei wählbaren Galerieordner heruntergeladen.

## Windows starten

Das neueste `VioraStudio-win-x64.zip` unter **Releases** herunterladen, vollständig entpacken und `VioraStudio.exe` starten. Windows x64, .NET-Laufzeit enthalten. Eigener SwarmUI-Server mit unterstützten Modellen und eine private HTTPS-Verbindung erforderlich.

1. Tailscale auf Server und Client verbinden.
2. In Einstellungen die private Serveradresse eintragen und einen Galerieordner auswählen/anlegen.
3. Speichern & verbinden, Modell und Stil wählen, Motiv beschreiben und generieren.
4. Ergebnisse liegen lokal. Bilder können direkt zu Video weiterverwendet werden.

## Funktionen

- Native WPF-Oberfläche, SDXL-Bilder und Wan 2.2 I2V HighNoise/LowNoise Q4.
- Anime, Animation und Real als Promptpresets; zusätzliche Stilmodelle werden nicht vorgetäuscht.
- Tatsächlicher Serverfortschritt, gerätebezogene Queue und Abbruch.
- Lokale Galerie, Favoriten, MP4-Vorschau und Export.
- GitHub-Updates mit Versionsvergleich und SHA-256-geprüftem Download. Der Nutzer schließt die App und ersetzt die EXE manuell. Einstellungen unter `%LOCALAPPDATA%\VioraStudio` und Galerie bleiben erhalten.

Die App besitzt noch kein Windows-Herausgeberzertifikat. Apple-Apps und SideStore-Feed werden separat auf dem Mac entwickelt; dieses Release enthält keine IPA/macOS-App.

## Entwicklung

.NET 8 SDK unter Windows. Quellstand in `src/`.

```powershell
dotnet build src/SwarmStudio.csproj -c Release
dotnet publish src/SwarmStudio.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -p:DebugType=None -o .runtime/publish
```

Die veröffentlichte EXE unterstützt `--selftest --output <Ordner>` für Prüfungen von Verbindungsadressen, Paketprüfsummen und Archivsicherheit. Echte Generierungstests benötigen einen laufenden privaten Server.

API-Vertrag und plattformübergreifende Abstimmung: `docs/api/swarm-v1.md`, `docs/APPLE-HANDOFF.md`. Persönliche Serveradressen, Galerie, Einstellungen, Zertifikate und Modellgewichte gehören nicht ins öffentliche Repository.
