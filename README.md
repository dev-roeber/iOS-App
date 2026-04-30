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
- **Live-Aufzeichnung**: ActivityKit Live Activity / Dynamic Island (iOS 16.2+ fuer Widget-/Island-UI), Fullscreen-Live-Karte, Follow-Location, optionaler HTTP(S)-Upload
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
  Tests/LocationHistoryConsumerTests/    — Unit-Tests (aktueller Nachweis: 660 Tests, 0 Failures)
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
- `swift test` → `660` Tests, `0` Failures

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
- Release-/Review-Truth 2026-04-30: App Store Connect zeigt `LH2GPX` Version `1.0` im Status `Warten auf Prüfung`; zur Version gehoert bewusst Build `52`. Xcode Cloud hat bereits erfolgreiche neuere Builds `55`, `56` und `57`, diese werden aber ohne Apple-Feedback oder bestaetigten release-kritischen Fehler nicht nachgereicht.
- Lokales `Release`-Archive fuer `LH2GPXWrapper` ist wieder erzeugbar (`1.0 (45)`), aber der Export-/Upload-Pfad zu TestFlight ist auf diesem Host noch blockiert, weil nur `Apple Development` lokal verfuegbar ist und `xcodebuild -exportArchive` deshalb kein Distribution-Zertifikat findet
