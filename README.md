# iOS-App — LH2GPX (LocationHistory2GPX)

**Dieses Repo (`dev-roeber/iOS-App`) ist das zentrale aktive Repository fuer die vollstaendige LH2GPX iOS-App.**

## Was die App macht

**LH2GPX ist eine öffentliche Consumer-/Utility-App für alle, die ihre persönliche Google-Maps-Standorthistorie lokal auswerten und als GPX/KML/CSV exportieren möchten.**

- Kein Account, kein Login, keine Organisationszugehörigkeit erforderlich
- Alle importierten Daten bleiben lokal auf dem Gerät des Nutzers
- Kein Pflicht-Server-Upload; die optionale Live-Aufzeichnung mit Server-Upload ist standardmäßig deaktiviert und erfordert explizite Nutzerkonfiguration eines eigenen Endpunkts

Kernfunktionen:

- Google Timeline JSON/ZIP (`location-history.json`, `.zip`) lokal importieren
- LH2GPX App-Export JSON/ZIP importieren
- GPX 1.1 und TCX 2.0 direkt importieren (auch innerhalb von ZIPs)
- Tagesansicht mit interaktiver Karte
- Tracks als GPX, KML, KMZ, GeoJSON oder CSV exportieren
- Google Maps Export-Hilfe (inline, Schritt-fuer-Schritt)

## Xcode-Einstieg

```
wrapper/LH2GPXWrapper.xcodeproj
```

1. `wrapper/LH2GPXWrapper.xcodeproj` in Xcode oeffnen
2. Scheme `LH2GPXWrapper` auswaehlen
3. Run auf iPhone oder Simulator

Das Swift Package im Root (`Package.swift`) wird automatisch als lokale Dependency eingebunden — kein separater Schritt noetig.

## Features

- **Import**: Google Timeline JSON/ZIP, LH2GPX App-Export JSON/ZIP, GPX 1.1, TCX 2.0
- **Tagesansicht**: Days-Liste (absteigend), Day-Detail mit Karte, Suche, Favoriten, Filterchips
- **Pfadmodus im Day-Detail**: Originalpfad oder vereinfachte Darstellung (`Simplified`); im vereinfachten Modus: GPS-Ausreisserfilter (distanzbasiert, PathFilter) + Douglas-Peucker; kein echtes Straßen-/Wege-Snapping
- **Live-Aufzeichnung**: ActivityKit Live Activity / Dynamic Island (iOS 16.2+ fuer Widget-/Island-UI), Fullscreen-Live-Karte, Follow-Location, optionaler HTTP(S)-Upload an einen selbst betriebenen Endpunkt (standardmäßig deaktiviert, kein zentraler Dienst, keine Organisationsbindung)
- **Insights**: Overview, Patterns, Breakdowns, KPI-Karten, Top Days, Monatstrends ohne 24-Monats-Cap, Heatmap
- **Export**: GPX, KML, KMZ, GeoJSON, CSV; Filter nach Datum, Genauigkeit, Aktivitaetstyp, Rectangle / Bounding Box (TCX nur als Import-Format unterstützt)
- **Google Maps Export-Hilfe**: Inline-Anleitung fuer iPhone-Export aus Google Maps
- **Lokalisierung**: Deutsch / Englisch
- **Widget / Sperrbildschirm**: Homescreen-Widget plus Live Activity / Dynamic Island fuer aktive Aufzeichnungen; Primärwert in der Island konfigurierbar (`Distanz`, `Dauer`, `Punkte`, `Upload-Status`), mit sichtbaren Fallback-Hinweisen wenn Live Activities auf dem Geraet nicht verfuegbar sind

## Repo-Struktur

```
Package.swift                          — Swift Package (Core Library)
Sources/
  LocationHistoryConsumer/             — AppExport-Modelle, Decoder, Queries
  LocationHistoryConsumerAppSupport/   — SwiftUI-UI, Session/Loader, Live-Domain
  LocationHistoryConsumerDemoSupport/  — Demo-Harness, Golden-Fixture
  LocationHistoryConsumerApp/          — Produkt-App-Einstieg
  LocationHistoryConsumerDemo/         — Demo-Einstieg
  Tests/LocationHistoryConsumerTests/    — Unit-Tests (aktueller Linux-Nachweis: 1400 Tests, 2 Skips, 0 Failures, 2026-05-09 HEAD `d629467`; Mac-Stand inkl. Apple-only-Cases höher)
Fixtures/contract/                     — Contract-Fixtures, Golden-JSONs
wrapper/LH2GPXWrapper.xcodeproj        — Xcode Wrapper (Signing, Bundle, App-Icon)
docs/                                  — Feature-Inventar, Runbook, Checklisten
ROADMAP.md                             — Delivery-Roadmap
NEXT_STEPS.md                          — Naechste offene Schritte
CHANGELOG.md                           — Versionshistorie
```

## Testen (SwiftPM)

```bash
swift test
```

Fuer Apple-komplette Testlaeufe auf macOS mit Xcode:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Aktueller Nachweis:
- **Mac (Stand 2026-05-12, post-CSQLite-Conditional-Fix):** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` → **1518 Tests, 4 Skips, 0 Failures** (111.0s). Die 4 Skips bestehen aus 2 vorab existierenden Skips plus 2 neuen Keychain-Accessibility-Read-Back-Tests, die auf macOS-File-Keychain das `pdmn`-Attribut nicht zurücklesen können — Save-Pfad selbst grün. `swift build` clean (79.2s). `xcodebuild -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED** (`CSQLite`-Linux-Shim jetzt conditional auf `.linux` in `Package.swift`; Apple-Plattformen nutzen SDK-`SQLite3` via `#if canImport(SQLite3)`-Gate in `LocalTimelineStore.swift`). `xcodebuild -destination 'id=00008130-…401C' build -allowProvisioningUpdates` **BUILD SUCCEEDED** auf iPhone 15 Pro Max (signed Debug-Build). Der vorherige `_sqlite3_*`-Linker-Bruch ist damit weg.
- **Linux (Stand 2026-05-09, HEAD `d629467` — vor Post-Pull-Audit):** `swift test` → 1400 Tests, 2 Skips, 0 Failures. Linux-Re-Run für HEAD `30015c9` wurde in diesem Train nicht gefahren.
- Vorher Mac 1081 Tests (HEAD `ae5de1f`, Memory-Peak-Fix).
- Vorher 1065 Tests (HEAD `3811bc3`, P1-Hardening-Train: distanceText\!-safe-unwrap, weak self in AppOverviewMapModel, Upload-URL-Validation + 8 neue URL-Validation-Tests).
- Vorher 1057 Tests (HEAD `5c69afe`, UX/Layout + Mock-Helper).
- Vorher 1045 Tests (HEAD `e3dae15`, Phase 1-5 Audit-Train).
- **Hardware-Acceptance iPhone 15 Pro Max (iOS 26.4) auf HEAD pending, 2026-05-12, alle 8 grün:** `testAppStoreScreenshots` PASSED (43.4 s), `testDeviceSmokeNavigationAndActions` PASSED (75.8 s, nach Heatmap-Button-Hit-Target-Fix + neuer `scrollUntilHittable`-Helper), `testLandscapeLayoutSmoke` PASSED (597.4 s, langsamer Run wegen DerivedData-Konkurrenz mit parallelem xcodebuild generic, Test selbst grün), `testLiveActivityHardwareCaptureDistance/Duration/Points/UploadStatusPendingAndRestart/UploadStatusFailed` alle PASSED (37–63 s).
- **46-MB-Crashfall bleibt FAILED / pending hardware retest** — `/Users/sebastian/Desktop/Google_Maps/12_05_2026_location-history.json` (46 657 867 Bytes / ~44.5 MiB) ist auf der Maschine verfügbar, der eigentliche Import auf dem iPhone erfordert aber manuelle UI-Interaktion (File Picker → Akzeptieren), die nicht autonom über `xcodebuild test` triggerbar ist. Hardware-Retest auf dem Release-Build ist für den Tester-Handoff vorbereitet, in diesem Train nicht durchgeführt. Der LocalTimelineStore-Pfad ist pre-production / feature-flagged / **default OFF** (`LH2GPX_LOCAL_TIMELINE_STORE`); 46-MB-Test bezieht sich nicht auf den Store-Pfad.
- **iPad-Layout** offen — iPad (UDID `3c955848…d4da0a5`, iPadOS 17.7.10) ist offline.
- **ASC / TestFlight / Apple Review** offen — extern, lokal nicht belegbar.

## Historische Vorstufen

Die folgenden Repos sind historische Vorstufen und werden nicht mehr aktiv weiterentwickelt:

| Repo | Status |
|------|--------|
| `dev-roeber/LocationHistory2GPX-Monorepo` | historisch / mirror |
| `dev-roeber/LocationHistory2GPX-iOS` | historisch |
| `dev-roeber/LH2GPXWrapper` | historisch |

## Externe Repos (bleiben separat)

- `dev-roeber/LocationHistory2GPX` — Python Producer-Pipeline fuer Google Rohdaten
- `dev-roeber/lh2gpx-live-receiver` — Beispiel-/Referenz-Implementierung eines selbst betriebenen Live-Location-Empfängers; rein optional, kein zentraler Dienst, kein Pflichtendpunkt der App

## CI / Xcode Cloud

- Xcode Cloud Minimal-CI vorbereitet: `wrapper/.xcode-version` (26.3), `wrapper/ci_scripts/` (post_clone, pre_xcodebuild, post_xcodebuild), `wrapper/CI.xctestplan` (Unit-Tests ohne UITests)
- Workflow-Anlage und App-ID-Registrierung: manuell in Xcode.app / Apple Developer Portal — Details: `docs/XCODE_CLOUD_RUNBOOK.md`
- `LH2GPXWrapperUITests` bewusst aus Cloud-Testplan ausgeschlossen (Location-Dialoge / Springboard-Interaktion in CI nicht stabil)

## Bewusst offen

- echtes Road-/Path-Matching a la Dawarich ist **nicht** implementiert; `Simplified` ist GPS-Ausreisserfilterung + Douglas-Peucker, kein Netzwerk-Snapping
- Auto-Resume (blind/automatisch) einer Live-Aufzeichnung nach App-Neustart ist **nicht** implementiert; Session-Restore mit User-Kontrolle (Banner `"Resume recording / Ignore"` (en) bzw. `"Aufzeichnung fortsetzen / Ignorieren"` (de)) ist implementiert (2026-04-13)
- Realer Device-Nachweis fuer Live Activity / Dynamic Island ist **teilweise** vorhanden: `iPhone 15 Pro Max` (`iOS 26.4`, Debug-Build) bestaetigt Recording-Start, Dynamic Island `compact` + `expanded` fuer Primärwert `Distanz` sowie Stop-/Dismiss-Verhalten; offen bleiben Lock Screen, `minimal`, weitere Primärwerte und Fallback-Pfade. Homescreen-Widget bleibt separat offen.
- Historien-Track-Editor: Mutations-Reset bei Import-Wechsel ist implementiert (`validateSource`, 2026-04-14); Export wendet Mutations jetzt an — gelöschte Routen verschwinden aus GPX/KMZ/KML/GeoJSON/CSV-Exports und aus der Export-Vorschau (Audit-Batch 2026-05-06, Block 1 Items 2-3, 5-6).
- Apple-Portal-/Signing-/TestFlight-/Device-UI-Themen sind auf diesem macOS-Host nicht voll verifizierbar und werden separat dokumentiert
- **App-Review-Stand**: Apple lehnte Version 1.0 (Build 74) am 2026-05-01 unter Guideline 3.2 (Business / Other Business Model Issues) ab; die Ablehnung basierte auf einer Fehleinschätzung als organisationsgebundene App. Review-Response wurde am 2026-05-05 gesendet und akzeptiert — Build 74 steht jetzt auf `Pending Developer Release`. Der 1.0-Train ist damit abgeschlossen; Folge-Train ist 1.0.1 (Cloud-Build 84 erfolgreich, `CURRENT_PROJECT_VERSION = 100` lokal gesetzt, Build ≥100 aus Xcode Cloud nötig vor nächstem Submit). Response-Entwurf: `docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md`.
- TestFlight-Submission läuft jetzt über Xcode Cloud (1.0.1-Train, Build 84 grün); der frühere lokale Blocker (`xcodebuild -exportArchive` ohne Distribution-Zertifikat) wird damit umgangen. Lokales `Release`-Archive bleibt für Smoke-Builds nutzbar (zuletzt erzeugbar als `1.0 (45)`-Snapshot am 2026-04-30, vor MARKETING_VERSION-Bump auf 1.0.1; aktueller lokaler Build-Stempel ist `1.0.1 (100)`).
- **Hardware-Verifikation auf iPhone 15 Pro Max**: am 2026-05-05 als letzte Hardware-Acceptance gefahren (`testAppStoreScreenshots`, `testDeviceSmokeNavigationAndActions`, `testLandscapeLayoutSmoke` PASSED). Hero-Map-Workspace, LiveStatusResolver, Export-Empty-State, fileExporter-Fix, Heatmap-Tier-1/2, Tempolayer/Halo-Strokes, SIGABRT-Defensivguards, MapLayerMenu (alle 2026-05-06) sind nur statisch + via Simulator (`xcodebuild` iPhone 17 Pro Max Sim 26.3.1 BUILD SUCCEEDED, 964 Tests grün) verifiziert — eine erneute Hardware-Verifikation steht aus.
