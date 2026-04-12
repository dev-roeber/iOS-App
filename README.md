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
- **Map-Matching Beta**: Douglas-Peucker Pfadvereinfachung (epsilon=15m), Toggle Original/Angepasst
- **Live-Aufzeichnung**: ActivityKit Live Activity (iOS 16.1+), Background-Recording, optionaler HTTP(S)-Upload
- **Insights**: Overview, Patterns, Breakdowns, KPI-Karten, Top Days, Monatstrends, Heatmap
- **Export**: GPX, TCX, KML, GeoJSON, CSV; Filter nach Datum, Genauigkeit, Aktivitaetstyp, Bounding Box
- **Google Maps Export-Hilfe**: Inline-Anleitung fuer iPhone-Export aus Google Maps
- **Lokalisierung**: Deutsch / Englisch

## Repo-Struktur

```
Package.swift                          — Swift Package (Core Library)
Sources/
  LocationHistoryConsumer/             — AppExport-Modelle, Decoder, Queries
  LocationHistoryConsumerAppSupport/   — SwiftUI-UI, Session/Loader, Live-Domain
  LocationHistoryConsumerDemoSupport/  — Demo-Harness, Golden-Fixture
  LocationHistoryConsumerApp/          — Produkt-App-Einstieg
  LocationHistoryConsumerDemo/         — Demo-Einstieg
Tests/LocationHistoryConsumerTests/    — Unit-Tests (546+, 0 Failures)
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
