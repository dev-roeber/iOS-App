# iOS-App — LH2GPX (LocationHistory2GPX)

**Dieses Repo (`dev-roeber/iOS-App`) ist das zentrale aktive Repository fuer die vollstaendige LH2GPX iOS-App.**

## Was die App macht

LH2GPX importiert Location History aus Google Timeline und exportiert sie als GPX oder TCX.

- Google Timeline JSON/ZIP (`location-history.json`, `.zip`) lokal importieren
- LH2GPX App-Export JSON/ZIP importieren
- GPX 1.1 und TCX 2.0 direkt importieren (auch innerhalb von ZIPs)
- Tagesansicht mit interaktiver Karte
- Tracks als GPX oder TCX exportieren
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
- **Live-Aufzeichnung**: ActivityKit Live Activity / Dynamic Island (iOS 16.1+), Fullscreen-Live-Karte, Follow-Location, optionaler HTTP(S)-Upload
- **Insights**: Overview, Patterns, Breakdowns, KPI-Karten, Top Days, Monatstrends ohne 24-Monats-Cap, Heatmap
- **Export**: GPX, TCX, KML, KMZ, GeoJSON, CSV; Filter nach Datum, Genauigkeit, Aktivitaetstyp, Bounding Box
- **Google Maps Export-Hilfe**: Inline-Anleitung fuer iPhone-Export aus Google Maps
- **Lokalisierung**: Deutsch / Englisch
- **Widget / Sperrbildschirm**: Homescreen-Widget plus Live Activity / Dynamic Island fuer aktive Aufzeichnungen

## Repo-Struktur

```
Package.swift                          — Swift Package (Core Library)
Sources/
  LocationHistoryConsumer/             — AppExport-Modelle, Decoder, Queries
  LocationHistoryConsumerAppSupport/   — SwiftUI-UI, Session/Loader, Live-Domain
  LocationHistoryConsumerDemoSupport/  — Demo-Harness, Golden-Fixture
  LocationHistoryConsumerApp/          — Produkt-App-Einstieg
  LocationHistoryConsumerDemo/         — Demo-Einstieg
  Tests/LocationHistoryConsumerTests/    — Unit-Tests (aktueller Linux-Nachweis: 616 Tests, 0 Skips, 0 Failures)
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

Aktueller Linux-Nachweis fuer dieses Repo:
- `swift test` → `616` Tests, `0` Skips, `0` Failures

## Historische Vorstufen

Die folgenden Repos sind historische Vorstufen und werden nicht mehr aktiv weiterentwickelt:

| Repo | Status |
|------|--------|
| `dev-roeber/LocationHistory2GPX-Monorepo` | historisch / mirror |
| `dev-roeber/LocationHistory2GPX-iOS` | historisch |
| `dev-roeber/LH2GPXWrapper` | historisch |

## Externe Repos (bleiben separat)

- `dev-roeber/LocationHistory2GPX` — Python Producer-Pipeline fuer Google Rohdaten
- `dev-roeber/lh2gpx-live-receiver` — Live-Receiver-Server fuer optionalen Upload-Endpunkt

## Bewusst offen

- echtes Road-/Path-Matching a la Dawarich ist **nicht** implementiert
- Auto-Resume einer laufenden Live-Aufzeichnung nach App-Neustart ist **nicht** implementiert
- Apple-Portal-/Signing-/TestFlight-/Device-UI-Themen sind auf diesem Linux-Host nicht voll verifizierbar und werden separat dokumentiert
