# iOS-App — LH2GPX (LocationHistory2GPX)

**Dieses Repo (`dev-roeber/iOS-App`) ist das zentrale aktive Repository fuer die vollstaendige LH2GPX iOS-App.**

> **Repo-Truth-Lock 2026-05-25 (verbindlich):** `https://github.com/dev-roeber/iOS-App` ist ab sofort das **einzige aktive Arbeits-Repo** für die LH2GPX iOS-App. Alle anderen LH2GPX-/LocationHistory2GPX-Repos (`LocationHistory2GPX-iOS`, `LH2GPXWrapper`, `LocationHistory2GPX-Monorepo`) sind **rein historisch** und werden nicht mehr als aktive Repo-Truth verwendet. `dev-roeber/LocationHistory2GPX` bleibt **externe Producer-Pipeline** (Fixture-Quelle, nicht Arbeitsrepo); `dev-roeber/lh2gpx-live-receiver` bleibt **externe optionale Beispiel-Implementierung** eines user-eigenen Live-Endpoints (kein zentraler Dienst). Details siehe `AGENTS.md` §Repo-Truth-Lock.

> **Repo-Truth-Patch 2026-05-25 (Xcode Cloud Build 190 extern grün + TestFlight 1.0.2 (190) verfügbar, `main` HEAD `b25c27d`):**
> - Xcode Cloud Workflow `Release – Archive & TestFlight` auf `b25c27d` durchgelaufen (Cloud-Umgebung Xcode 26.5 / macOS Tahoe 26.4): Archive – iOS ✅, TestFlight-interne Tests – iOS ✅. TestFlight zeigt `LH2GPX 1.0.2 (190)`, 90 Tage verfügbar, App öffnet sich, Startscreen lädt ohne Crash. Build 179 → 190.
> - **Apple Developer Portal Container `iCloud.de.roeber.LH2GPXWrapper` extern bestätigt** (Cloud-Distribution-Signing + TestFlight-Aufnahme akzeptieren das Provisioning Profile mit beiden iCloud-Entitlement-Keys).
> - **TestFlight-Smoke nur teilweise:** App-Launch + Startscreen ohne Crash geprüft; alle weiteren Bereiche (Overview/Import/Tage/Karte/Heatmap/Insights/Export/Live/Settings/iCloud-Sichtprüfung/Bereichswechsel) **nicht geprüft** — Details siehe CHANGELOG-Block.
> - Echter iCloud-Sync, CloudKit-Records, Historien-Sync, Public/shared DB, iPad, Light Mode, App Review-Submission für 1.0.2 (190), LHX*-UI-Adoption: weiter **nicht** behauptet.

> **Repo-Truth-Patch 2026-05-25 (Train F.1 Apple-Host-validiert, `main` HEAD `2845d82` + Package.swift macOS-Bump):**
> - Apple-Host-Validierung auf macOS 15.7 / Xcode 26.3 / iPhone 15 Pro Max iOS 26.4 lokal durchgeführt. `xcodebuild` Sim Build/Test ✅, Device Build mit Signing ✅, App-Launch ohne Crash, Device UITests 12/13 (1 Fail `testDeviceSmokeNavigationAndActions`-Hit-Target). `swift build`/`swift test` macOS-Host ✅ (1558/2/0 in 186 s) nach Package.swift `.macOS(.v13)`→`.v14`-Bump (Hotfix für seit 16.05. kaputtes macOS-CLI nach onChange-Migration in `ff963c1`).
> - **Apple Developer Portal Container `iCloud.de.roeber.LH2GPXWrapper` registriert** — implizit nachgewiesen via Provisioning-Profile + Embedded-Entitlements im signierten Device-Bundle.
> - Echter Sync, CloudKit-Records, Historien-Sync, Public/shared DB, iPad, Light Mode, Xcode Cloud auf neuem HEAD, TestFlight, ASC: weiter **nicht** behauptet. Siehe `docs/APPLE_VERIFICATION_CHECKLIST.md` Block 2026-05-25.

> **Repo-Truth-Patch 2026-05-22 (Train F.1 — iCloud Capability Preparation, Branch `feature/icloud-capability-f1`):**
> - `wrapper/LH2GPXWrapper/LH2GPXWrapper.entitlements` erweitert um
>   `com.apple.developer.icloud-container-identifiers = [iCloud.de.roeber.LH2GPXWrapper]`
>   und `com.apple.developer.icloud-services = [CloudKit]`. Widget-
>   Entitlement unverändert.
> - Neuer `Sources/LocationHistoryConsumerAppSupport/CloudKitCloudSyncService.swift`,
>   `#if canImport(CloudKit)`-gegated. Nur `CKAccountStatus`-Mapping —
>   **kein** Sync, **keine** Records, **keine** Subscriptions, **keine**
>   Public DB, **keine** Historien-Synchronisation.
> - **Apple Developer Portal Container `iCloud.de.roeber.LH2GPXWrapper`
>   noch NICHT registriert** — Pflicht-Apple-Schritt vor jedem signierten
>   Mac-Build (siehe `docs/ICLOUD_SYNC_ARCHITECTURE.md` §2a + §5).
> - Privacy-Manifest unverändert (kein neuer Datentyp gesammelt — kommt
>   erst mit Train F.2).
> - Linux: `swift build` ✅, `swift test` ✅ 1578/2/0.
> - iPhone-only, Force-Dark, LocalTimelineStore default OFF — unverändert.

> **Historischer Repo-Truth-Patch 2026-05-22 (Branch `main`, HEAD `4f0813a` — Audit-Report-merge):**
> - Neuer Audit-Report `docs/DEEP_AUDIT_FULL_APP_REDESIGN_ICLOUD_2026-05-22.md`
>   (read-only Tiefenaudit + iCloud-Machbarkeit + Train-Reihenfolge).
> - Begleitende Spezifikation `docs/APP_REDESIGN_INTERACTION_SPEC_2026-05-22.md`
>   (auf Branch `chore/redesign-interaction-spec`).
> - **App ist heute iPhone-only** — `TARGETED_DEVICE_FAMILY = 1` in allen 8
>   Configs. iPad-Layout ist im Code (`regularSplitView`) vorhanden, aber
>   nicht freigeschaltet; frühere Doku-Aussage „iPad-Layout offen / iPad
>   offline" wird damit präziser gefasst.
> - **iCloud ist heute nicht implementiert** — keine `iCloud.*`-Entitlement,
>   kein CloudKit, kein `NSUbiquitous*`. Saved Live Tracks und der
>   LocalTimelineStore sind `isExcludedFromBackup = true`. iCloud-Plan
>   ist *Phase A/B/C* in der Spec, **keine** Implementation.
> - **Force-Dark-UI** — `preferredColorScheme(.dark)` plus harte schwarze
>   Backgrounds. `UIUserInterfaceStyle = Dark` ist im Info.plist *noch
>   nicht* gesetzt (Train A).
> - `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171`
>   unverändert. Linker extern grüner Build laut historischer Doku =
>   Xcode Cloud Build 179 auf `ff789a4` (Train M tip).
> - In diesem Patch wurden **keine Tests gefahren, keine Builds, keine
>   Code-Änderungen**.

> **Historischer Repo-Truth-Patch 2026-05-19 (Branch `main`, HEAD `31c4351` — Train R tip):**
> - `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171` (8 pbxproj-Configs + Info.plist App/Widget konsistent) — unverändert.
> - Linux `swift test` heute auf HEAD `31c4351`: **1578 Tests, 2 Skips, 0 Failures, 54,67 s** (+143 ggü. 1435-Snapshot in §"Repo-Struktur" / §"Testen", der den Stand 2026-05-16 HEAD `71f715b` festhält). Trains M–R sind seither gemerged.
> - Audit-Bericht: `docs/DEEP_AUDIT_DOC_TRUTH_SYNC_2026-05-19.md`.
> - Apple-/Xcode-/ASC-/Hardware-Aussagen in diesem README werden im Audit 2026-05-19 **nicht** re-verifiziert (Linux-Host); historische Snapshots in §"Testen" und §"Bewusst offen" bleiben mit ihrem Originaldatum stehen.

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
- **Live-Aufzeichnung**: ActivityKit Live Activity / Dynamic Island (iOS 17 Minimum seit Train F 2026-05-16; Dynamic Island weiterhin nur auf iPhone 14 Pro und neuer), Fullscreen-Live-Karte, Follow-Location, optionaler HTTP(S)-Upload an einen selbst betriebenen Endpunkt (standardmäßig deaktiviert, kein zentraler Dienst, keine Organisationsbindung)
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
  Tests/LocationHistoryConsumerTests/    — Unit-Tests (aktueller Linux-Nachweis: 1435 Tests, 2 Skips, 0 Failures, 2026-05-16 HEAD `71f715b`, Swift 6.3.2; Mac-Stand inkl. Apple-only-Cases höher — 1524/2/0 am 2026-05-13)
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
- **Mac (Stand 2026-05-12, post-performance-audit + low-risk-optimizations):** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` → **1521 Tests, 4 Skips, 0 Failures** (113.5 s, +3 ggü. 1518 — die drei neuen Tests in `PathDistanceCalculatorPerformanceTests.swift`) (111.0s). Die 4 Skips bestehen aus 2 vorab existierenden Skips plus 2 neuen Keychain-Accessibility-Read-Back-Tests, die auf macOS-File-Keychain das `pdmn`-Attribut nicht zurücklesen können — Save-Pfad selbst grün. `swift build` clean (79.2s). `xcodebuild -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED** (`CSQLite`-Linux-Shim jetzt conditional auf `.linux` in `Package.swift`; Apple-Plattformen nutzen SDK-`SQLite3` via `#if canImport(SQLite3)`-Gate in `LocalTimelineStore.swift`). `xcodebuild -destination 'id=00008130-…401C' build -allowProvisioningUpdates` **BUILD SUCCEEDED** auf iPhone 15 Pro Max (signed Debug-Build). Der vorherige `_sqlite3_*`-Linker-Bruch ist damit weg.
- **Linux (Stand 2026-05-16, HEAD `71f715b`, Swift 6.3.2 via swiftly):** `swift build` Build complete (6.34 s) und `swift test` → **1435 Tests, 2 Skips, 0 Failures (41,1 s)**. Voraussetzung: `libsqlite3-dev` installiert. Vorher: 1400/2/0 am 2026-05-09 HEAD `d629467`.
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
- **App-Review-Stand**: Apple lehnte Version 1.0 (Build 74) am 2026-05-01 unter Guideline 3.2 (Business / Other Business Model Issues) ab; die Ablehnung basierte auf einer Fehleinschätzung als organisationsgebundene App. Review-Response wurde am 2026-05-05 gesendet — Build 74 stand danach laut Doku auf `Pending Developer Release` (extern, im Repo nicht aus jüngerem Datum re-verifiziert). Folge-Train: 1.0.1 (Cloud-Build 84 historisch erfolgreich) wurde durch 1.0.2 abgelöst; aktueller Repo-Stempel ist `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171` (pbxproj + Info.plist konsistent). Response-Entwurf: `docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md`. **ASC-Live-Status nicht im Audit 2026-05-16 verifiziert.**
- TestFlight-Submission läuft über Xcode Cloud. Repo-Truth (Stand 2026-05-16): pbxproj + Info.plist (App + Widget) auf `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171`. Lokales `xcarchive` wurde am 2026-05-13 für `1.0.2 (171)` erzeugt (`/tmp/lh2gpx-release/LH2GPXWrapper-build171.xcarchive`); **nicht hochgeladen** — manueller Organizer-Upload steht aus. ASC-Status (Build 74 / 1.0 `Pending Developer Release`) bleibt extern und ist im Repo nicht prüfbar. Frühere lokale Stempel `1.0.1 (100)` und `1.0 (45)` sind historisch.
- **Hardware-Verifikation auf iPhone 15 Pro Max**: zuletzt erweitert am **2026-05-13** (Post-Audit-Closure-Train) auf iOS 26.4. `xcodebuild test -only-testing:LH2GPXWrapperUITests` **TEST SUCCEEDED** — **9 UI-Tests + 4× LaunchTest passed in 1299,77 s** (8 Bestands-Tests + neuer `testLargeImportSyntheticFile` mit synthetischer 46-MiB-Google-Timeline-style JSON: passed in 126,27 s, kein Crash/Hang/Jetsam, App nach Import bedienbar). Damit ist das 46-MiB-Hardware-Gate für die Streaming-/Parser-/Loader-Pipeline **autonom geschlossen**; ein gesonderter Tester-Handoff ist für die 46-MiB-Klasse nicht mehr nötig. `swift test` 1524/2/0 (157 s, Mac-Host, +3 ggü. 1521). Heatmap-Hit-Target-Fix `f111afd` weiter wirksam (Bestands-Tests 8/8). Davor 2026-05-05 Hardware-Acceptance (Bestands-Tests PASSED). Hero-Map-Workspace, LiveStatusResolver, Export-Empty-State, fileExporter-Fix, Heatmap-Tier-1/2, Tempolayer/Halo-Strokes, SIGABRT-Defensivguards, MapLayerMenu (alle 2026-05-06) sind über die 2026-05-13-Hardware-Acceptance abgedeckt. *Hinweis zur Genauigkeit von `testLargeImportSyntheticFile`*: Synthetisches Asset (visit-only Entries), nicht das originale Tester-Asset (timelinePath-Geometrie); die *Klasse* der 46-MiB-Streaming-Last ist verifiziert.
