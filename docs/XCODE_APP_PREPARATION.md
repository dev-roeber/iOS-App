# Xcode App Preparation

## Zweck

Diese Notiz beschreibt die kleinste aktuell sinnvolle Apple-/Xcode-nahe Vorbereitung in diesem Repo.
Sie fuehrt bewusst kein `.xcodeproj` und keine ungetesteten Produkt-App-Dateien ein.
Das konkrete operative Runbook liegt ab Phase 11 in `docs/XCODE_RUNBOOK.md`, die konkrete Pruefliste in `docs/APPLE_VERIFICATION_CHECKLIST.md`.

## Aktueller Einstieg

Der vorgesehene Apple-/Xcode-nahe Einstieg ist weiterhin das Swift Package:

```bash
open Package.swift
```

Alternativ kann das Verzeichnis in Xcode geoeffnet werden. Die produktnahe App-Schicht liegt im Target `LocationHistoryConsumerApp`.

## Schichten

- `LocationHistoryConsumer`
  - Consumer-Core fuer Contract, Decoder und Query-Layer
- `LocationHistoryConsumerDemoSupport`
  - fixture-zentrierte Demo-Unterstuetzung
- `LocationHistoryConsumerDemo`
  - lokale Harness-/Verifikationsoberflaeche
- `LocationHistoryConsumerAppSupport`
  - produktnahe Session-, Import- und Inhaltsdarstellungs-Helfer
- `LocationHistoryConsumerApp`
  - kleiner produktnaher App-Einstieg fuer lokalen `app_export.json`-Import

## Was fuer Apple vorbereitet ist

- SwiftUI-basierte Demo- und App-Shell-Targets sind im Swift Package getrennt vorhanden.
- `LocationHistoryConsumerApp` ist import-first und als spaetere Apple-Produkt-App-Huelle positioniert.
- Gemeinsame app-nahe Session-/Import-Logik ist in `LocationHistoryConsumerAppSupport` gekapselt statt in Demo-Views.
- Das Repo bleibt offline-first und konsumiert den eingefrorenen Consumer-Contract; lokal unterstuetzt die App inzwischen LH2GPX-`app_export.json`-/`.zip`-Import sowie den begrenzten Google-Timeline-Import. Optionaler nutzergesteuerter Upload betrifft nur akzeptierte Live-Recording-Punkte und ist standardmaessig deaktiviert.

## Was bewusst noch nicht vorbereitet ist

- kein `.xcodeproj` im Core-Package-Root (der Wrapper unter `wrapper/LH2GPXWrapper.xcodeproj` hat sein eigenes Xcode-Projekt mit Info.plist, Bundle-Config, App-Icon und PrivacyInfo.xcprivacy)
- kein signierter Apple-App-Build direkt aus dem Core-Package
- keine `Info.plist`-/Bundle-/Icon-/Entitlement-Ausarbeitung im Core-Package-Root (diese liegen alle im `wrapper/`)
- kein Cloud-/Account-Sync fuer importierte History; optionaler Server-Upload ist separat, standardmaessig deaktiviert und in diesem Audit nicht neu auf Apple-Hardware verifiziert
- keine hardware-verifizierte Background-Recording-Session oder Auto-Resume laufender Live-Tracks

**Hinweis Wrapper:** Der Xcode-Wrapper unter `wrapper/LH2GPXWrapper.xcodeproj` ist bereits vollständig mit Info.plist, Bundle-Identifier `de.roeber.LH2GPXWrapper`, Signing-Team `XAGR3K7XDJ`, Deployment Target iOS 16.0 (App, Tests) / 16.2 (Widget, UITests), `wrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy` und `ITSAppUsesNonExemptEncryption = false` (App + Widget Info.plist) ausgestattet. Fuer den Release-/App-Store-Pfad ist der Repo-Truth ab 2026-04-30: `CODE_SIGN_STYLE = Automatic`, keine feste Release-`PROVISIONING_PROFILE_SPECIFIER`, keine explizite Release-`CODE_SIGN_IDENTITY`, `CURRENT_PROJECT_VERSION = 45`, Widget-Embed via `CodeSignOnCopy`. App Store Connect zeigt fuer `LH2GPX` inzwischen Version `1.0` im Status `Warten auf Prüfung`; auf der Versionsseite ist Build `52` sichtbar, waehrend Xcode Cloud erfolgreiche Builds `55` bis `57` ausweist. Lokal ist `xcodebuild archive` wieder erfolgreich; `xcodebuild -exportArchive` bleibt auf diesem Host mangels Distribution-Zertifikat blockiert. Die Aussage "kein `.xcodeproj`" gilt nur für den Core-Package-Root, nicht für das Monorepo insgesamt.

## Export-Compliance

Die App nutzt ausschließlich systemseitige Verschlüsselung (HTTPS/TLS via URLSession). Eigene Kryptografie (CryptoKit, CommonCrypto, AES, RSA, VPN, E2E-Messaging, proprietäre Crypto-Bibliotheken) ist nicht vorhanden. `ITSAppUsesNonExemptEncryption = false` ist in beiden App-Store-Targets gesetzt:

- `wrapper/Config/Info.plist` — Haupt-App (`de.roeber.LH2GPXWrapper`)
- `wrapper/LH2GPXWidget/Info.plist` — Widget-Extension (`de.roeber.LH2GPXWrapper.Widget`)

Damit sind beim App-Store-Upload **keine Export-Compliance-Unterlagen** erforderlich.

## Performance-Schutzschicht Overview-Map

`AppOverviewTracksMapView` verwendet eine tiered Render-Pipeline mit Hard Overlay Limit:
- Sammelt Track-Daten off-Main-Thread via `Task.detached`
- Scannt den Export nur bei Daten-/Filterwechsel; Pan/Zoom rebuildet nur Overlays aus dem gecachten Kandidatenpool
- Nutzt Bounding-Box-Intersection fuer Viewport-Priorisierung, damit lange sichtbare Routen nicht wegen eines außerhalb liegenden Midpoints verschwinden
- Wählt Top-Kandidaten nach Score aus und capped auf `overlayLimit` (150–300 je nach Datenmenge)
- Vereinfacht jeden Kandidaten via Douglas-Peucker + stride-Decimation
- Setzt `isOptimized = true` wenn Limit oder Vereinfachung greift; Badge im View informiert den Nutzer
- **Export bleibt vollständig und unberührt** — nur die visuelle Kartenrepräsentation wird reduziert

## Lokale Verifikation

Unter Linux ist ehrlich verifiziert:

- `swift test` (647 Tests, 0 Failures am 2026-04-29)
- Linux-Build der SwiftPM-Targets
- Linux-Fallback-Mains der Apple-UI-nahen Executables

Unter Linux ist nicht verifiziert:

- echter Xcode-Run
- echter iOS-/macOS-SwiftUI-Lauf
- `fileImporter` auf Apple-Plattformen
- Signierung, Sandbox, Bundle-Metadaten
- jeder neue `xcodebuild`-Nachweis fuer den aktuellen Repo-Stand, weil `xcodebuild` auf diesem Host nicht vorhanden ist

Stand 2026-03-17 ist auf einer echten macOS-/Xcode-Maschine zusaetzlich verifiziert:

- Xcode 26.3 erkennt die Swift-Package-Schemes
- `LocationHistoryConsumerApp` baut fuer macOS erfolgreich via `xcodebuild`
- das gebaute Binary laesst sich starten und blieb bis zum manuellen Abbruch aktiv
- `swift test` laeuft mit dem echten Xcode-Developer-Dir gruen

Stand 2026-03-17 wurde zusaetzlich in Phase 11/12 verifiziert:

- sichtbarer interaktiver UI-Run mit manuell bestaetigter Fensterdarstellung
- `Load Demo Data`, `Open location history file`, `Clear` und Fehlerfaelle als echte UI-Durchgaenge
- Details siehe `docs/APPLE_VERIFICATION_CHECKLIST.md`

Wichtig fuer diese konkrete Maschine: das aktive `xcode-select` zeigte auf `/Library/Developer/CommandLineTools`; deshalb wurden Xcode-Build und SwiftPM-Test bewusst ueber `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` ausgefuehrt.

## Naechster Apple-Schritt

Wenn eine echte Apple-Validierung moeglich ist, sollte der naechste kleine Schritt nicht neue Features oeffnen, sondern:

1. `Package.swift` in Xcode oeffnen
2. `LocationHistoryConsumerApp` als Apple-App-Shell pruefen
3. minimale Apple-Bundle-Metadaten nur dann ergänzen, wenn sie fuer einen echten lokalen Run noetig sind
4. weiterhin keine neue Apple-/Review-Behauptung ohne echten Apple-Host-Nachweis einfuehren
