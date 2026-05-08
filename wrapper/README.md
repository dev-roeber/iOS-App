# LH2GPXWrapper

Xcode-Wrapper-Projekt fuer die iOS-App von LocationHistory2GPX.

**Aktiver Repo-Kontext:** Dieses `wrapper/`-Verzeichnis lebt heute im aktiven Repo `iOS-App`. Aeltere Hinweise auf `LocationHistory2GPX-Monorepo` sind nur noch historischer Kontext.

> **Hinweis 2026-05-08 (Build-158-Vorbereitung — interne Test-Toggles für TestFlight)**: Build 157 ist Xcode Cloud grün und TestFlight-installierbar (Status „Überprüft", interne Tests erfolgreich) — keine Aussage über Apple-Review-Freigabe oder über das 46-MB-Hardwareverhalten. Da TestFlight-Tester **keine Launch-Argumente / Environment-Variablen** setzen können, ist im Core-Paket als Build-158-Vorbereitung eine UserDefaults-basierte Toggle-Strecke ergänzt, die der Wrapper über die bestehende Settings → Technical-Sektion automatisch sichtbar macht: "Internal Test Toggles" mit zwei Bool-Toggles `LH2GPX.localTimelineStoreTestModeEnabled` (LocalTimelineStore-Pfad) und `LH2GPX.importMemoryLoggingEnabled` (Import-Memory-Logging). **Args/ENV bleiben primärer Aktivator** (lokale Xcode-Runs); das Setting aktiviert **zusätzlich** (TestFlight-Strecke), deaktiviert nichts. `ImportMemoryProbe.isLoggingEnabled` ist computed → Toggle wirkt **ohne Relaunch**. Wrapper-Code (`wrapper/LH2GPXWrapper/`/`wrapper/LH2GPXWidget/`) ist nicht angefasst; Wrapper-Bundle/Signing/Plist/Asset unverändert; keine neuen externen Dependencies. Privacy-/Scope-Vertrag: nur Bool unter den beiden Keys, **keine Standortdaten / keine Pfade / keine Tokens**. LocalTimelineStore-Pfad bleibt **default AUS, pre-production / feature-flagged**; Toggle ist interner Testmodus. Live-Upload, Recording, Auth-Flows unberührt. **46-MB-Crashfall bleibt FAILED / pending hardware retest** (verbatim). **Keine ASC/Review/Hardware-Freigabe behauptet**, **keine Map-Phase-10B-Aussage**.

> **Hinweis 2026-05-08 (Phase 10A)**: Zusätzlich zu Phase 9A/9B reicht der Wrapper jetzt eine neue `LH2GPXAppFlow.makeProductionDayMapSource(for: storeSession)` an die `LocalTimelineSessionLandingView` durch. Bei aktivem Feature-Flag (`LH2GPX_LOCAL_TIMELINE_STORE`) zeigt jeder geöffnete Day jetzt zusätzlich eine optionale Map-Sektion: "Load map" (bounded Candidate-Load **ohne `coord_blob`-Decodierung**) und "Decode all routes" (bounded Geometrie-Decode innerhalb harter `Budget`-Grenzen — default 12 Routen / 256 Punkte pro Route / 4096 Punkte gesamt). Die View ist ein SwiftUI Placeholder (`LocalTimelineDayMapView`, `#if canImport(SwiftUI)`-guarded) **ohne MapKit-Import**; echte `MKMapView`-/`MKMultiPolyline`-Verdrahtung bleibt **Phase-10B Mac/Xcode-Pflicht**. **Vollständige sichtbare Kartenmodernisierung wird nicht behauptet.** Legacy-Map unverändert. **Store-Pfad bleibt default AUS**; keine Wrapper-Bundle-/Signing-/Plist-Änderung; keine neuen externen Dependencies; 46-MB-Crashfall bleibt FAILED / pending hardware retest.

> **Hinweis 2026-05-08 (Phase 9B)**: Zusätzlich zu Phase 9A (Envelope-Pfad + Settings-Delete-Button + Landing-View) reicht der Wrapper jetzt `LH2GPXAppFlow.makeProductionDayBrowserSource(for: storeSession)` + Selection-Binding (`AppSessionState.selectedLocalTimelineDayId` / `selectLocalTimelineDay(_:)`) an die `LocalTimelineSessionLandingView` durch. Bei aktivem Feature-Flag (`LH2GPX_LOCAL_TIMELINE_STORE`) sehen Tester nach Google-Timeline-Import jetzt eine **Tagesliste** (`LocalTimelineDayListView`, newest-first) und können pro Tag eine sheet-basierte **DayDetail-Ansicht** (`LocalTimelineDayDetailView` mit Visits + Activities + Path-Metadaten + Hinweis "Path points available (not decoded)") öffnen — **kein eager `coord_blob`-Decoding, keine Karte**. Der **Store-Pfad bleibt feature-flagged via `LH2GPX_LOCAL_TIMELINE_STORE`, default AUS** — Default-Rollout bleibt Legacy-AppExport. Keine Wrapper-Bundle-/Signing-/Plist-Änderung; keine neuen externen Dependencies; 46-MB-Crashfall bleibt FAILED / pending hardware retest.

> **Hinweis 2026-05-08 (Phase 9A)**: Der Wrapper ist auf den feature-flagged Envelope-Pfad (`loadImportedFileEnvelope` + `LH2GPXAppFlow.apply(envelopeOutcome:to:preserveOnFailure:)`) verdrahtet und zeigt bei aktiver `localTimelineSession` die `LocalTimelineSessionLandingView` aus dem Core-Paket; Settings → Technical enthält eine Section "Local Timeline Store" mit Feature-Flag-Status und Delete-Button.

> **Hinweis 2026-05-08 (Phase 10A P1-A/B Weg 2):** Bei aktivem "Local Timeline Store Test Mode" (Settings → Technical) zeigt der Wrapper während eines Google-Timeline-Imports eine sichtbare Progress-Card mit Status, Counter und Cancel-Button. Cancel rollback'd die offene SQLite-Transaktion und truncate't WAL — es bleibt kein Teilimport zurück, ein Reimport ist sofort möglich. Store-Pfad bleibt feature-flagged / default OFF; 46-MB-Hardware-Gate bleibt FAILED / pending hardware retest.

## Rolle dieses Verzeichnisses

- Xcode-Projekt (.xcodeproj) fuer die fertige iOS-App
- bindet das Core-Swift-Package aus dem Monorepo-Root als lokales Swift Package ein
- liefert Bundle-Metadaten, App-Icon, Privacy-Manifest und Signing-Konfiguration
- ist der Weg zu Geraetedeploy, TestFlight und App Store
- ist bewusst nicht die fachliche Truth-Quelle fuer Parsing-/Export-/Importlogik; diese bleibt im Root-Package

## Repo-Architektur

| Aspekt | Core (Monorepo-Root) | Wrapper (`wrapper/`) |
|--------|----------------------|---------------------|
| Pfad | `/` (Repo-Root, `Package.swift`) | `wrapper/` |
| Inhalt | Swift Package: Decoder, Queries, AppSupport, DemoSupport | Xcode-Projekt: App-Target, Bundle-Config, Assets |
| Build | `swift build` / `swift test` im Root | `xcodebuild` mit `-project wrapper/LH2GPXWrapper.xcodeproj` |
| Tests | Unit-Tests via SwiftPM (~1034 Linux / erwartet ~1133 Mac, GitHub Actions `.github/workflows/swift-test.yml`) | Xcode-Unit- und UI-Tests (Xcode Cloud via `wrapper/CI.xctestplan`, nur Wrapper-Targets) |

> **Hinweis Test-Plan-Split:** `wrapper/CI.xctestplan` enthaelt bewusst nur das Wrapper-Test-Target `LH2GPXWrapperTests`. Die SwiftPM-Tests (`LocationHistoryConsumerPackageTests`) — Stand 2026-05-08 nach Linux-Stabilisierung **1034 Tests grün auf Linux** (HEAD `37a22b7` nach `34bc369`), erwarteter Mac-Stand **~1133** mit allen iOS-only Tests hinter `canImport(SwiftUI)`/`MapKit`/`CoreLocation`/`UIKit` — sind nicht als Xcode-Test-Target im Wrapper-`project.pbxproj` registriert und laufen separat via GitHub Actions (`.github/workflows/swift-test.yml`). Eine Integration in den xctestplan wuerde voraussetzen, das SwiftPM-Test-Produkt als nativen Test-Target-Eintrag in der pbxproj zu fuehren — aktuell out-of-scope, da risikobehaftet fuer die Project-Datei.
| Abhaengigkeit | eigenstaendig | haengt vom Core ab (lokale SPM-Referenz `..`) |

## SPM-Abhaengigkeit

Das Xcode-Projekt referenziert den Core als lokales Swift Package:

```
..
```

(relativ zum `wrapper/`-Verzeichnis; zeigt auf den Monorepo-Root mit `Package.swift`)

Genutzte Produkte:
- `LocationHistoryConsumerAppSupport` – Produkt-UI (NavigationSplitView, Dashboard, Day-Detail, Map), Session, Loader, Bookmark-Persistenz, Live-Recording-Domain
- `LocationHistoryConsumerDemoSupport` – Demo-Fixture-Loader

## Bundle-Konfiguration

- **Bundle Identifier:** `de.roeber.LH2GPXWrapper`
- **Display Name:** LH2GPX
- **Version:** 1.0.1 (`MARKETING_VERSION`); 1.0-Train abgeschlossen — Build 74 in ASC-Status `Pending Developer Release` (akzeptiert nach Review-Response 2026-05-05); 1.0.1-Train Xcode Cloud Build 84 grün; `CURRENT_PROJECT_VERSION = 100` lokal gesetzt (commit `8854eef`, 2026-05-06), Xcode Cloud Build ≥100 vor nächstem Submit nötig (Stand 2026-05-06)
- **Deployment Target:** iOS 16.0 (App + Tests) / iOS 16.2 (`LH2GPXWidget`). Die Inkonsistenz ist bewusst: ActivityKit Live Activities erfordern iOS 16.2 und sind in `wrapper/.../LH2GPXWidget/Info.plist` verankert; der App-Pfad bleibt auf 16.0, damit ältere iPhones die App weiter nutzen können (Widget/Live-Activity-UI fällt dort sichtbar zurück).
- **Signing:** Automatic (Team XAGR3K7XDJ); lokaler Release-Archive-Pfad baut derzeit mit `Apple Development`, weil auf diesem Host keine Distribution-Identitaet verfuegbar ist
- **App Icon:** Map-Pin + "LH2GPX", 1024x1024 (Interims-Design, kein Gradient-Placeholder mehr)
- **Privacy Manifest:** `PrivacyInfo.xcprivacy` – kein Tracking; UserDefaults-Zugriff (CA92.1) und `NSPrivacyCollectedDataTypePreciseLocation` fuer den optionalen, standardmaessig deaktivierten Live-Upload sind deklariert; lokale Live-Location nutzt die Info.plist-Usage-Strings fuer While-In-Use plus optionale `Always Allow`-Erweiterung

## Lokaler Build

In Xcode:
1. `wrapper/LH2GPXWrapper.xcodeproj` oeffnen
2. Scheme `LH2GPXWrapper` waehlen
3. Zielgeraet oder Simulator waehlen
4. Product > Run

Per CLI:
```bash
cd ~/Desktop/XCODE/iOS-App

xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj \
  -scheme LH2GPXWrapper \
  -destination 'generic/platform=iOS' \
  build
```

## Produkt-UI (Phase 17–20)

Die App nutzt die Produkt-UI aus dem Core-Repo (`LocationHistoryConsumerAppSupport`):
- NavigationSplitView mit Day-Liste und Detail-Pane
- compact iPhone-Layout mit `Overview`, `Days`, `Insights`, `Export` und auf iOS 17+ einem dedizierten `Live`-Tab
- Overview-Dashboard mit Statistik-Grid
- Day-Detail mit strukturierten Sections und Cards
- Karten-MVP: MapKit-Ansicht im Day-Detail mit Pfad-Polylines und Visit-Markern
- Heatmap als eigenes Sheet fuer importierte History auf iOS 17+/macOS 14+
- Dynamic-Island-Primärwert (`Distanz`, `Dauer`, `Punkte`, `Upload-Status`) ist in den Optionen konfigurierbar; nicht verfuegbare Live Activities werden im Wrapper sichtbar als nicht konfigurierbar ausgewiesen
- Live-Recording-Sektion im Day-Detail: manueller Toggle, aktueller Standort, Live-Polyline, gespeicherte Live-Tracks
- dedizierter Live-Tab mit Fullscreen-Karte, Follow-/Recenter-Aktion, Upload-Status und Zugriff auf die gespeicherten Live-Tracks
- Optionen-Seite ueber das Actions-Menue: lokale Distanz-Einheit, Start-Tab, Kartenstil, Sprache, technische Importdetails, Widget-/Dynamic-Island-Optionen und optionaler Server-Upload
- VoiceOver-Accessibility: semantische Labels und Gruppierung fuer alle Kernelemente
- Toolbar-Aktionen mit SF-Symbol-Icons, inklusive Optionen-Seite
- Konsistente Leer-/Fehler-/Ladezustaende
- Edge-Case-Hardening: defensive Guards, robuste Formatierung

## Lokaler iPhone-Betrieb

### Hardware-Acceptance — iPhone 15 Pro Max (2026-05-07, HEAD pending — Commit folgt)

Hardware-Re-Verifikation auf iPhone 15 Pro Max (iOS 26.4, UDID `00008130-00163D0A0461401C`), Xcode 26.3 (17C529), App 1.0.1 (100), Bundle `de.roeber.LH2GPXWrapper`, Team XAGR3K7XDJ:

- `testAppStoreScreenshots`: PASSED (42.9s)
- `testDeviceSmokeNavigationAndActions`: PASSED (72.2s)
- `testLandscapeLayoutSmoke`: PASSED (830s)
- `swift test`: 1077 Tests, 2 Skips, 0 Failures (unverändert)
- Wrapper xcodebuild auf iPhone 15 Pro Max: BUILD + TEST SUCCEEDED

Während des Runs P1-UX-Bug gefunden und gefixt: `HistoryDateRangeFilterBar` clear-date-range Button (`xmark.circle.fill`) hatte 12×12pt Hit-Area — unter Apple HIG-Mindestmaß 44×44pt und auf Hardware nicht zuverlässig tap-fähig (XCUITest „Failed to not hittable"). Fix: `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` um das Button-Image; visible Glyph unverändert.

Weiterhin offen: 46-MB-Crashfall geräteseitig (manueller Import nötig, kein UITest); Live Activity / Dynamic Island / Lock-Screen visuell (Always-Permission braucht UI); ASC / TestFlight / Apple Review nicht geprüft.

**Day-Detail-Distance-Fix kam nach Acceptance**: Nach den drei oben gelisteten UITests wurde der Day-Detail-Distance-Bug gefixt (`PathDistanceCalculator` + `effectiveDistanceM` in `DayDetailViewState.PathItem`, 12 neue Test-Cases). `swift test` post-Fix 1077/2/0. Device-Smoke nach Fix erneut PASSED (`testDeviceSmokeNavigationAndActions` auf iPhone 15 Pro Max iOS 26.4, 75s). Volle 3-UITest-Suite (`testAppStoreScreenshots` / `testLandscapeLayoutSmoke`) post-Fix nicht erneut gefahren.

Verifiziert (2026-03-17):
- `xcodebuild build` erfolgreich (generic/platform=iOS)
- iPhone 15 Pro Max + iPhone 12 Pro Max: Deploy, Demo, Karte, Day-Detail, Scrollen
- Import `app_export.json`: funktioniert
- Persistenz / Restore nach App-Neustart: historisch auf 2026-03-17 verifiziert; der seit 2026-03-20 wieder aktive Wrapper-Auto-Restore braucht fuer den aktuellen Code-Stand eine frische Device-Re-Verifikation

Erneut verifiziert (2026-04-12):
- `make deploy` baut den Wrapper und startet `de.roeber.LH2GPXWrapper` erfolgreich auf `iPhone_15_Pro_Max` und `iPhone_12_Pro_Max`

Neu auf Code-Stand 2026-03-18:
- Google-Takeout-`location-history.json` und `.zip` werden direkt unterstuetzt
- Live-Location / Live-Recording ist eingebaut (lokal, manuell gestartet; optionaler Background-Modus im aktuellen Code)
- Live-Tracks werden getrennt von importierter History gespeichert; kein Auto-Resume nach Neustart
- generischer iOS-Build ist auf aktuellem Stand lokal gruen; ein frischer Simulator-Testlauf fuer `LH2GPXWrapperTests` konnte auf diesem Host am 2026-04-29/30 nicht belastbar abgeschlossen werden (`NSMachErrorDomain Code=-308` beim App-Launch)

Neu auf Code-Stand 2026-03-19:
- eine echte lokale Optionen-Seite ist eingebaut
- Einstellungen wirken app-weit im Wrapper, weil die Preferences-Domain im Core-Repo zentral injiziert wird
- bewusst keine Cloud-, Server- oder Sync-Toggles

Neu auf Code-Stand 2026-03-20:
- `ContentView` ruft `restoreBookmarkedFile()` beim Start wieder auf; der Wrapper-Auto-Restore ist damit aktiv, waehrend die Core-App-Shell weiter manuell startet
- der Wrapper deklariert jetzt auch die iOS-Voraussetzungen fuer optionales Background-Live-Recording (`Always Allow`-Usage-String + `location`-Background-Mode)
- der ueber das Core-Repo gelieferte Export-Flow kann jetzt `GPX`, `KML` und `GeoJSON`
- Export unterstuetzt jetzt die Modi `Tracks`, `Waypoints` und `Both`
- lokale Exportfilter decken jetzt auch Bounding Box und Polygon fuer importierte History ab
- die ueber das Core-Repo gelieferte Produkt-UI bringt jetzt auch den dedizierten `Live`-Tab sowie ein Heatmap-Sheet mit
- Optionen bieten jetzt Deutsch/Englisch und optionalen Server-Upload fuer akzeptierte Live-Recording-Punkte
- der Standard-Testendpunkt fuer den Server-Upload ist leer (`""`); der Nutzer muss seinen eigenen HTTPS-Endpunkt in den Optionen eintragen
- Deep Link `lh2gpx://live` navigiert direkt zum Live-Tab (z.B. aus dem Widget)
- URL-Scheme `lh2gpx://` ist per `CFBundleURLTypes` in `Config/Info.plist` registriert
- App Groups (`group.de.roeber.LH2GPXWrapper`) fuer Widget-Datenaustausch konfiguriert (Entitlements in `LH2GPXWrapper/` und `LH2GPXWidget/`)
- JSON, ZIP, GPX, TCX koennen per `fileImporter` geoeffnet werden (KML/GeoJSON-Export wird unterstuetzt, der Import-Picker akzeptiert sie aktuell nicht)

Aktueller Server-Truth fuer den eingebundenen Core-Stand:
- Linux-Vollsuite ist nach der Linux-Stabilisierung 2026-05-08 (HEAD `37a22b7` nach `34bc369` — HeatmapPreferenceEnums-Extraktion, OptionsPresentation-Hoisting, URL/autoreleasepool/Foundation-Guards, neue `LinuxStabilizationRegressionTests` mit 7 Cases) wieder **grün**: `swift build` (Vollbuild) clean, `swift build --build-tests` clean, `swift test` **1034 Tests, 2 Skips, 0 Failures** auf Linux. Erwarteter Mac-Stand (post-Linux-Stabilisierung, mit allen iOS-only Tests hinter `canImport(SwiftUI)`/`MapKit`/`CoreLocation`/`UIKit`): **~1133** (1033 Linux + ~100 iOS-only). **46-MB-Crashfall bleibt FAILED** bis Hardware-Retest auf iPhone 15 Pro Max (Mac/iPhone-Handoff). Davor: `swift test` im aktiven Repo `iOS-App` lief lokal grün mit `1077` Tests, `2` Skips und `0` Failures (Stand 2026-05-07, HEAD `3811bc3` — P1-Hardening-Train: distanceText! safe-unwrap in `DaySummaryRowPresentation`, `[weak self]` in `AppOverviewMapModel.rebuildOverlays`, Upload-URL-Validation in `AppPreferences.liveLocationServerUploadURLString` (akzeptiert https / localhost / 127.0.0.1 / [::1]; rejected http remote / garbage), 8 neue Tests in `AppPreferencesUploadURLValidationTests.swift`. Vorher 1057 unter HEAD `5c69afe` (UX/Layout-Train + Mock-Helper). Vorher 1057 unter HEAD `20877ae` Phase 1-5 Audit-Train: 14 Achsen über zwei Commits — `21b4026` (Phase 1: `projectedDays`-Cache, Mutations-Index, Race-Token, Live-Map-Dedup, `@testable`-Cleanup-Folge) + `20877ae` (Phase 2-5: Mock-Client + State-Transition-Tests, `LH2GPXAppFlow` Drift-Extraction + Auto-Restore-Phasen, API-Naming als additives Importing-Protokoll (kein Rename), `wrapper/CI.xctestplan` SwiftPM-Coverage als SKIP dokumentiert — pbxproj-Integration zu fragil, `Tests/README.md` Update, Doku-Truth-Cleanup). +1 Case gegenüber 1044 (Mock-Refactor ersetzt Placeholder durch zwei echte Cases). Hardware-Re-Verifikation iPhone 15 Pro Max bleibt für jeden Stand seit 2026-05-05 offen. Davor 1044 unter Audit-Batch B+C+D+A: 22 Achsen — Dead-Code-Removal in `AppDayDetailView`/`AppContentSplitView`, Löschung `LHSharedMapChrome.swift` (`LHMapStyleToggleButton` public API entfernt — war deprecated, keine externen Caller bekannt; ~158 Zeilen weniger), Perf-Restposten (`OverviewMapRenderData: Equatable`, inline Haversine, `HeatmapGridBuilder` Single-Sort+`suffix`-Trim, `AppExportQueries.findDay` Fast-Path), `@testable import` → reines `import` für 15 von 22 Test-Files, 9 neue Test-Files mit 27 neuen Cases (Decoder/GPX/TCX-Errors, Round-Trip, Filter-Kombinationen, Heatmap-Edge-Cases, Live-State-Transition-Placeholder, Export-Mutations, ZIP-Streaming-Pfad). `wrapper/CI.xctestplan` SKIP (pbxproj-Integration out-of-scope), API-Naming P2-16 + HeatmapGridBuilder MapKit-Entkopplung P2-18 bewusst not done. +27 Cases gegenüber 1017. Davor 1017 unter Audit Block 1-2-Train: `WidgetSharedKeys.swift` als Single-Source-of-Truth für App-Group-Suite + UserDefaults-Keys (P1-3 `WidgetDataStore`-Duplikat geschlossen, Wrapper-Mirror um `saveDynamicIslandCompactDisplay` ergänzt); `onOpenURL`-Modifier im Package-App-Target `AppShellRootView` (P1-4 erledigt — `lh2gpx://live` greift jetzt auch dort); ZIP-Entry-Streaming für Google Timeline (`AppContentLoader.streamGoogleTimelineCandidateIfApplicable`, Sniffer-basiert; greift bei genau einem Timeline-Entry und keinem Mixed-ZIP — Peak RAM auf ~ein Element); neuer `enum ImportPhase { reading, parsing, building }` plus `LoadingProgressEngine.phase`/`setPhase(_:)`; lokalisierte Phase-Labels im Wrapper-`ContentView`; XCTest-`measure`-Baseline-Logging für den Streaming-Parser (kein fail-on-regression bar). 5 neue Cases gegenüber 1012. Davor 1012 unter HEAD post-`70254ff` nach Audit-Batch Block 1-4 (19 Achsen: Datenverlust-Wiring inkl. Mutations-fließen-jetzt-in-Exporte, Concurrency, Edge-Case-Crashes, Performance-Hotspots — Tests unverändert, bestehende Tests laufen über die neuen Pfade) plus P0-Audit-Fix-Train 3/N: GPX-Crash-Härtung in `GPXImportParser` (`as!`-Force-Cast und `fatalError` entfernt — Parser kann auf malformiertem GPX nicht mehr SIGABRT-en), KeychainHelper-`kCFBooleanTrue!`-Force-Unwrap entschärft (`true as CFBoolean`), `AppExportSchemaVersion` ist jetzt forward-kompatibel (`struct` mit `rawValue: String` plus `isSupportedByThisBuild` — zukünftige Tool-Versionen decodieren, statt mit `unknownSchemaVersion` abgelehnt zu werden); danach Einführung des element-basierten Streaming-Parsers für Google Timeline JSON: neue Datei `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineStreamReader.swift` plus `GoogleTimelineConverter.convertStreaming(contentsOf:)` für direkte JSON-Imports ohne Full-Data-Load; der Streaming-Reader nutzt einen UnsafeBytes-Tokenizer (256-KB-Chunks, `@inline(__always)`-Hot-Path, `autoreleasepool` um den Per-Element-Callback) und direct-model-build im Konverter (`AppExport` wird direkt über public memberwise-Initializer gebaut, kein `[String: Any]`-Tree und kein JSON-Roundtrip auf der Output-Seite). ZIP-Entry-Streaming bleibt offen — ZIPFoundation extrahiert weiterhin in `Data`. Hardware-Re-Verifikation 46-MB-Datei auf iPhone 15 Pro Max steht aus. Vorher 991 nach Memory-Safety-Folgefix; 987 nach erstem Memory-Safety-Fix, 973 nach LH2GPXLoadingBackground, 964 nach Doku-/Wiring-Audit-Polish, 949 am 2026-05-06 09:57)
- `xcodebuild -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.3.1' build`: BUILD SUCCEEDED auf macOS lokal, HEAD `3811bc3` (Stand 2026-05-07 nach P1-Hardening-Train; iPhone 15 Pro Max ist die physische Hardware-Verifikations-Plattform — kein passender Sim mehr installiert; Hardware-Re-Verifikation für diesen HEAD steht aus)
- iPhone 15 Pro Max physisch (UDID `00008130-00163D0A0461401C`, iOS 26.4): `testAppStoreScreenshots`, `testDeviceSmokeNavigationAndActions`, `testLandscapeLayoutSmoke` alle PASSED am 2026-05-05 (Build vor Hero-Map-Rollout); Hero-Map-/LiveStatus-/Export-Fix-Änderungen vom 2026-05-06 noch nicht erneut auf Hardware verifiziert

Unterstuetztes Import-Format: jede `.json`-Datei oder `.zip`-Datei, die einen gueltigen LH2GPX-App-Export enthaelt, plus Google-Timeline-`location-history.json` / `.zip` aus Google Takeout.

Vollstaendiges Device-Runbook: `docs/LOCAL_IPHONE_RUNBOOK.md`

iPad: bewusst spaeter.

## TestFlight + App Store Readiness

Lokal verifiziert (2026-04-30, historisch — nach Build-Bumps inzwischen `1.0.1 (100)`):
- `xcodebuild archive` erfolgreich (`1.0 (45)` zum damaligen Zeitpunkt)
- `PrivacyInfo.xcprivacy` deklariert UserDefaults-Zugriff (CA92.1) und `PreciseLocation` fuer den optionalen Live-Upload

Offen:
- Apple-Review-Scope fuer die inzwischen eingetragene `PreciseLocation`-Deklaration des optionalen Server-Uploads bleibt ungeklaert
- App Review Guidelines 5.1.1 (Data Collection) und 5.1.2 (Privacy Manifests): teilweise – kein abschliessender Nachweis der Konformitaet fuer den Upload-Pfad
- ein manueller Xcode-Start auf dem verbundenen iPhone bleibt ein positiver Teilbefund, ist aber bewusst getrennt von den CLI-Build-/Test-Ergebnissen zu lesen

Lokal abgeschlossen (2026-04-29):
- App Icon: Map-Pin + "LH2GPX" (kein Gradient-Placeholder mehr)
- Screenshots erstellt: `docs/app-store-assets/screenshots/`
  - `iphone-67/`: 1290×2796 px (iPhone 15 Pro Max, native 3×) — 6 PNGs ✅
  - `iphone-65/`: 1242×2688 px (proportional skaliert) — 6 PNGs ✅
  - Methode: `testAppStoreScreenshots` UITest → XCTAttachment → xcresult-Extraktion
  - Daten: ausschließlich Repo-Demo-Fixture, keine privaten Nutzerdaten
  - Keine Debug-Overlays, keine Server-URLs, keine Tokens sichtbar
- `docs/privacy.html`: Datenschutzerklärung für App Store Connect (GitHub Pages)
- `ITSAppUsesNonExemptEncryption = false`: in App + Widget Info.plist gesetzt
- iPad: fuer v1 aktuell nicht im Release-Build vorgesehen (`TARGETED_DEVICE_FAMILY = 1`); iPad-Screenshots sind deshalb nicht erforderlich

Aktueller ASC-Truth (Stand 2026-05-06):
- Version `1.0` Build `74` ist nach Review-Response (2026-05-05) **akzeptiert**, ASC-Status `Pending Developer Release` — bewusst nicht freigegeben, 1.0-Train damit geschlossen
- Builds `80`–`83` (1.0-Train) wurden wegen geschlossenem Train mit ITMS-90186 / ITMS-90062 verworfen — kein Code-Fehler
- `MARKETING_VERSION` im `project.pbxproj` ist auf `1.0.1` angehoben; ASC hat Version `1.0.1` angelegt
- Xcode Cloud Build `84` (1.0.1-Train) ist erfolgreich (Archive ✓, TestFlight Internal ✓)
- Build `95` ist veraltet — `CURRENT_PROJECT_VERSION` lokal auf `100` angehoben (commit `8854eef`); Build `≥100` muss aus Xcode Cloud getriggert werden, damit der MapLayerMenu-/Heatmap-/Tempolayer-/SIGABRT-Fix-Stand vom 2026-05-06 enthalten ist

Weiterhin manuell / ASC-abhaengig:
- App Store Connect Projekt anlegen
- Screenshots in ASC hochladen (`iphone-67/`-Slot: 6.7-inch Display)
- Privacy URL eintragen: `https://dev-roeber.github.io/iOS-App/privacy.html`
- Upload / TestFlight-Beta
  - aktueller lokaler Blocker: `xcodebuild -exportArchive` scheitert mit `No signing certificate "iOS Distribution" found`
  - zusaetzlicher lokaler Blocker: `altool` hat keine konfigurierte ASC-Authentifizierung (weder JWT noch Username/App-Password)

Vollstaendiger Submission-Leitfaden: `docs/TESTFLIGHT_RUNBOOK.md`

## Was bewusst noch nicht vorbereitet ist

- kein finales App-Icon-Design (Interims-Icon vorhanden, finales Branding-Design steht aus)
- keine vollstaendige Lokalisierung; derzeit partielle Deutsch/Englisch-Abdeckung aus dem Core-Repo
- keine Heatmap-Produktreife- oder Performance-Verifikation, kein Replay, keine Offline-Karten
- kein echtes Road-/Path-Matching
- kein Resume laufender Live-Tracks, kein Cloud-/Sync-Flow fuer importierte History, keine frische Device-Verifikation fuer optionales Background-Live-Recording

## Roadmap

Die kanonischen Planungsdateien liegen im Root dieses aktiven Repos:
- [ROADMAP.md](/Users/sebastian/iOS-App/ROADMAP.md)
- [NEXT_STEPS.md](/Users/sebastian/iOS-App/NEXT_STEPS.md)
