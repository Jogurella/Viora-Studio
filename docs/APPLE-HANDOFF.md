# Apple-Entwicklung

Produktname Viora Studio. Native SwiftUI-Clients für iPhone und macOS, keine WebView. Windows liegt in `src/`; Änderungen daran mit dem Windows-Stand abstimmen. Apple-Quellstand im Ordner `apple/` und Branch `codex/apple` anlegen.

Gemeinsamer Vertrag: `api/swarm-v1.md`. Nutzer hat Designreferenzen als SwarmUI-Oberflaeche.zip geliefert; die ausführliche private Übergabe wurde ihm separat übergeben. Die HTMLs sind Mockups mit Platzhaltern/Fake-Timern, kein Produktionscode.

Dunkles Glasdesign: Hintergrund #06070B, Purple #6D4CFF, Cyan #14B8D4, Pink #FF5C8A. iPhone: Erstellen/Galerie/Queue/Modelle, Safe Areas, Dynamic Type, Touchziele mindestens 44pt. Mac: anpassbare Mehrspaltenansicht. Bilder/Videos, drei Stilpresets, reale Modellauswahl, echter Fortschritt, Queue, Abbruch, Galerie und Favoriten.

Mac-Galerie in einem frei wähl-/anlegbaren lokalen Ordner, Zugriff über security-scoped Bookmark. iPhone interne Galerie, optional explizit Fotos/Dateien/Teilen. Ergebnisse tatsächlich auf das Clientgerät herunterladen. Einstellungen und Galerie bei Updates erhalten.

Privater HTTPS-Server wird vom Nutzer eingetragen. Persönlichen Endpunkt, Zertifikate und Medien nicht einchecken. Der Windows-Server stellt SwarmUI und RTX3060 12GB mit SDXL sowie Wan2.2 I2V Q4 bereit.

iOS: GitHub-Releases mit tatsächlich gebauter/signierter IPA plus SideStore-kompatiblem Feed. Signing und Geräteinstallation verifizieren; keine Platzhalter-IPA veröffentlichen. macOS: GitHub/Sparkle mit EdDSA, ggf. Apple-Signierung/Notarisierung. SideStore gilt nur für iOS.

Versionsnummern und API-Änderungen gemeinsam dokumentieren. Pro Plattform `docs/status/` pflegen. Keine automatische Chatkopplung voraussetzen; sie war beim Übergabeversuch technisch nicht verfügbar.
