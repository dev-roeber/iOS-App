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
- **Pfadmodus im Day-Detail**: Originalpfad oder vereinfachte Darstellung (`Simplified (Beta)`); im vereinfachten Modus: GPS-Ausreisserfilter (distanzbasiert, PathFilter) + Douglas-Peucker; kein echtes Straßen-/Wege-Snapping
- **Live-Aufzeichnung**: ActivityKit Live Activity / Dynamic Island (iOS 16.2+ fuer Widget-/Island-UI), Fullscreen-Live-Karte, Follow-Location, optionaler HTTP(S)-Upload an einen selbst betriebenen Endpunkt (standardmäßig deaktiviert, kein zentraler Dienst, keine Organisationsbindung)
- **Insights**: Overview, Patterns, Breakdowns, KPI-Karten, Top Days, Monatstrends ohne 24-Monats-Cap, Heatmap
- **Export**: GPX, TCX, KML, KMZ, GeoJSON, CSV; Filter nach Datum, Genauigkeit, Aktivitaetstyp, Bounding Box
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
  Tests/LocationHistoryConsumerTests/    — Unit-Tests (aktueller Nachweis: 987 Tests, 2 Skips, 0 Failures, 2026-05-06)
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
- `swift test` → `987` Tests, `2` Skips, `0` Failures (Stand 2026-05-06, HEAD post-`70254ff` nach Memory-Safety-Fix gegen Jetsam-Kill bei großen Google-Timeline-Imports)

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

- echtes Road-/Path-Matching a la Dawarich ist **nicht** implementiert; `Simplified (Beta)` ist GPS-Ausreisserfilterung + Douglas-Peucker, kein Netzwerk-Snapping
- Auto-Resume (blind/automatisch) einer Live-Aufzeichnung nach App-Neustart ist **nicht** implementiert; Session-Restore mit User-Kontrolle (Banner "Fortsetzen / Ignorieren") ist implementiert (2026-04-13)
- Realer Device-Nachweis fuer Live Activity / Dynamic Island ist **teilweise** vorhanden: `iPhone 15 Pro Max` (`iOS 26.4`, Debug-Build) bestaetigt Recording-Start, Dynamic Island `compact` + `expanded` fuer Primärwert `Distanz` sowie Stop-/Dismiss-Verhalten; offen bleiben Lock Screen, `minimal`, weitere Primärwerte und Fallback-Pfade. Homescreen-Widget bleibt separat offen.
- Historien-Track-Editor: Mutations-Reset bei Import-Wechsel ist implementiert (`validateSource`, 2026-04-14); Export ignoriert Mutations bewusst (AppExport ist immutable, Mutations sind display-only)
- Export ignoriert Mutations bewusst — gelöschte Routen bleiben im GPX/KMZ-Export (AppExport ist immutable; Mutations sind rein display-only)
- Apple-Portal-/Signing-/TestFlight-/Device-UI-Themen sind auf diesem macOS-Host nicht voll verifizierbar und werden separat dokumentiert
- **App-Review-Stand**: Apple lehnte Version 1.0 (Build 74) am 2026-05-01 unter Guideline 3.2 (Business / Other Business Model Issues) ab; die Ablehnung basierte auf einer Fehleinschätzung als organisationsgebundene App. Review-Response wurde am 2026-05-05 gesendet und akzeptiert — Build 74 steht jetzt auf `Pending Developer Release`. Der 1.0-Train ist damit abgeschlossen; Folge-Train ist 1.0.1 (Cloud-Build 84 erfolgreich, `CURRENT_PROJECT_VERSION = 100` lokal gesetzt, Build ≥100 aus Xcode Cloud nötig vor nächstem Submit). Response-Entwurf: `docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md`.
- TestFlight-Submission läuft jetzt über Xcode Cloud (1.0.1-Train, Build 84 grün); der frühere lokale Blocker (`xcodebuild -exportArchive` ohne Distribution-Zertifikat) wird damit umgangen. Lokales `Release`-Archive bleibt für Smoke-Builds nutzbar (zuletzt erzeugbar als `1.0 (45)`-Snapshot am 2026-04-30, vor MARKETING_VERSION-Bump auf 1.0.1; aktueller lokaler Build-Stempel ist `1.0.1 (100)`).
- **Hardware-Verifikation auf iPhone 15 Pro Max**: am 2026-05-05 als letzte Hardware-Acceptance gefahren (`testAppStoreScreenshots`, `testDeviceSmokeNavigationAndActions`, `testLandscapeLayoutSmoke` PASSED). Hero-Map-Workspace, LiveStatusResolver, Export-Empty-State, fileExporter-Fix, Heatmap-Tier-1/2, Tempolayer/Halo-Strokes, SIGABRT-Defensivguards, MapLayerMenu (alle 2026-05-06) sind nur statisch + via Simulator (`xcodebuild` iPhone 17 Pro Max Sim 26.3.1 BUILD SUCCEEDED, 964 Tests grün) verifiziert — eine erneute Hardware-Verifikation steht aus.
