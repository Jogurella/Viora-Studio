# Apple-Auslieferung

Gemeinsame Produktversion 0.1.0, Apple-Build 2, API-Vertrag v1 mit `api/apple-v1.md`. Das vorhandene öffentliche Windows-Release v0.1.0 bleibt unabhängig. Ein Release wird nicht allein durch den erfolgreichen Build veröffentlicht.

## iPhone

Bundle-ID `com.jogurella.viorastudio`, iOS 17+, iPhone, keine Zusatz-Entitlements. Fotos-AddOnly-Nutzung ist in Info.plist erklärt und wird erst bei der Aktion angefragt. Aktuell liegt eine echte, lokal exportierte Apple-Development-IPA vor. Das persönliche Profil ist kurzfristig gültig; Ablauf siehe lokalen Prüfbericht/Provisioning. Diese IPA enthält ein persönliches Profil und Gerätekennungen und wird deshalb nicht automatisch in ein öffentliches Repository hochgeladen.

Archivierung mit dem eigenen, lokal verfügbaren Team:

```sh
xcodebuild -project apple/VioraStudio.xcodeproj -scheme VioraStudio -configuration Release \
  -destination 'generic/platform=iOS' -archivePath /APFS/VioraStudio-iOS.xcarchive \
  DEVELOPMENT_TEAM=DEINTEAM -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath /APFS/VioraStudio-iOS.xcarchive \
  -exportPath /APFS/Export -exportOptionsPlist /privat/ExportOptions.plist -allowProvisioningUpdates
```

ExportOptions lokal mit `method: debugging`, `signingStyle: automatic`, eigenem `teamID` für Entwicklungsgeräte erzeugen. Für öffentliche Verteilung muss der passende Apple-/SideStore-Signierungsweg separat gewählt werden. Niemals eine unsignierte Datei als installierbar ausgeben. SideStore kann eine IPA importieren und gemäß seinen tatsächlichen Regeln neu signieren/erneuern; die App selbst verspricht keine automatische Installation.

`updates/make-apple-source.py` erstellt erst aus einer realen IPA und einer bereits erreichbaren, bytegleichen Release-URL eine Source-JSON. Version, Größe, Bundle-ID, Betriebssystemgrenze und Berechtigungen werden aus dem Artefakt abgeleitet. Das Script lädt nichts hoch. Es gibt absichtlich noch keinen aktiven Feed.

Offizieller Quellenvertrag (geprüft 04.11.2026): [AltStore Make a Source](https://faq.altstore.io/developers/make-a-source) und [App Permissions](https://faq.altstore.io/developers/app-permissions). Vor Veröffentlichung die aktuell verwendete SideStore-Version mit dem erzeugten Feed testen; ein gültiges JSON allein belegt keinen erfolgreichen Import.

## macOS

macOS 14+, Apple Silicon wurde lokal geprüft. Lokaler Release-Build mit ad-hoc-Signatur kann auf diesem Mac gestartet werden. Für Verteilung an andere Macs fehlen Developer-ID-Signierung und Notarisierung. ZIP muss das App-Bundle inklusive ausführbarer Rechte/Symlinks bewahren (`ditto -c -k --keepParent`). Installation/Update erfolgt vorerst manuell; Galerie und Einstellungen liegen außerhalb des App-Bundles.

Sparkle ist bewusst noch nicht eingebunden. Dafür müssen eine verwahrte EdDSA-Identität, `SUPublicEDKey`, reale HTTPS-Appcast-URL, signierte ZIP und ein geprüfter Update-/Relaunchpfad für die Sandbox vorliegen. [Offizielle Sparkle-Dokumentation](https://sparkle-project.org/documentation/). SideStore ist kein macOS-Updater.

## Gemeinsame Freigabe

Vor dem Veröffentlichen reale Artefakte mit SHA-256, API-Kompatibilität, Plattformtests und bekannte Einschränkungen in die Release-Notizen aufnehmen. Ein gemeinsamer Tag benennt nur tatsächlich vorhandene Plattformdateien. Windows-Code und dessen Releasepfad bleiben unverändert. Apple-CI baut/testet, veröffentlicht aber nichts.
