# LH2GPXWrapper

Xcode-Wrapper-Projekt fuer die iOS-App von LocationHistory2GPX.

**Aktiver Repo-Kontext:** Dieses `wrapper/`-Verzeichnis lebt heute im aktiven Repo `iOS-App`. Aeltere Hinweise auf `LocationHistory2GPX-Monorepo` sind nur noch historischer Kontext.

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
| Tests | Unit-Tests via SwiftPM | Xcode-Unit- und UI-Tests |
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
- **Deployment Target:** iOS 16.0 (App) / iOS 16.2 (Widget)
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
- `swift test` im aktiven Repo `iOS-App` lief lokal grün mit `1006` Tests, `2` Skips und `0` Failures (Stand 2026-05-06, HEAD post-`70254ff` nach Einführung des element-basierten Streaming-Parsers für Google Timeline JSON: neue Datei `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineStreamReader.swift` plus `GoogleTimelineConverter.convertStreaming(contentsOf:)` für direkte JSON-Imports ohne Full-Data-Load; der Streaming-Reader nutzt einen UnsafeBytes-Tokenizer (256-KB-Chunks, `@inline(__always)`-Hot-Path, `autoreleasepool` um den Per-Element-Callback) und direct-model-build im Konverter (`AppExport` wird direkt über public memberwise-Initializer gebaut, kein `[String: Any]`-Tree und kein JSON-Roundtrip auf der Output-Seite). ZIP-Entry-Streaming bleibt offen — ZIPFoundation extrahiert weiterhin in `Data`. Hardware-Re-Verifikation 46-MB-Datei auf iPhone 15 Pro Max steht aus. Vorher 991 nach Memory-Safety-Folgefix; 987 nach erstem Memory-Safety-Fix, 973 nach LH2GPXLoadingBackground, 964 nach Doku-/Wiring-Audit-Polish, 949 am 2026-05-06 09:57)
- `xcodebuild -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.3.1' build`: BUILD SUCCEEDED auf macOS lokal, HEAD post-`70254ff` (2026-05-06; iPhone 15 Pro Max ist die physische Hardware-Verifikations-Plattform — kein passender Sim mehr installiert)
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
