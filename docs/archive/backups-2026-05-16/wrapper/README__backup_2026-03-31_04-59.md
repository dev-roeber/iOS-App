# LH2GPXWrapper

Xcode-Wrapper-Projekt fuer die iOS-App von LocationHistory2GPX.

## Rolle dieses Repos

- Xcode-Projekt (.xcodeproj) fuer die fertige iOS-App
- bindet das Core-/Consumer-Repo `LocationHistory2GPX-iOS` als lokales Swift Package ein
- liefert Bundle-Metadaten, App-Icon, Privacy-Manifest und Signing-Konfiguration
- ist der Weg zu Geraetedeploy, TestFlight und App Store

## Zwei-Repo-Architektur

| Aspekt | Core-Repo (`LocationHistory2GPX-iOS`) | Wrapper-Repo (`LH2GPXWrapper`) |
|--------|----------------------------------------|-------------------------------|
| Pfad | workspace-lokaler Checkout des Core-Repos | workspace-lokaler Checkout des Wrapper-Repos |
| Inhalt | Swift Package: Decoder, Queries, AppSupport, DemoSupport | Xcode-Projekt: App-Target, Bundle-Config, Assets |
| Build | `swift build` / `swift test` | `xcodebuild` / Xcode IDE |
| Tests | Unit-Tests via SwiftPM | Xcode-Unit- und UI-Tests |
| Abhaengigkeit | keins (eigenstaendig) | haengt vom Core-Repo ab (lokale SPM-Referenz) |

## SPM-Abhaengigkeit

Das Xcode-Projekt referenziert das Core-Repo als lokales Swift Package:

```
../LocationHistory2GPX-iOS
```

Genutzte Produkte:
- `LocationHistoryConsumerAppSupport` – Produkt-UI (NavigationSplitView, Dashboard, Day-Detail, Map), Session, Loader, Bookmark-Persistenz, Live-Recording-Domain
- `LocationHistoryConsumerDemoSupport` – Demo-Fixture-Loader

## Bundle-Konfiguration

- **Bundle Identifier:** `de.roeber.LH2GPXWrapper`
- **Display Name:** LH2GPX
- **Version:** 1.0 (Build 1)
- **Deployment Target:** iOS 26.2
- **Signing:** Automatic (Team XAGR3K7XDJ)
- **App Icon:** Map-Pin + "LH2GPX", 1024x1024 (Interims-Design, kein Gradient-Placeholder mehr)
- **Privacy Manifest:** `PrivacyInfo.xcprivacy` – kein Tracking, UserDefaults-Zugriff deklariert; lokale Live-Location ueber Info.plist-Usage-Strings fuer While-In-Use plus optionale `Always Allow`-Erweiterung; der optionale nutzergesteuerte Server-Upload von Live-Standortpunkten ist standardmaessig deaktiviert und erfordert aktive Konfiguration

## Lokaler Build

In Xcode:
1. `LH2GPXWrapper.xcodeproj` oeffnen
2. Scheme `LH2GPXWrapper` waehlen
3. Zielgeraet oder Simulator waehlen
4. Product > Run

Per CLI:
```bash
xcodebuild -project LH2GPXWrapper.xcodeproj \
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
- Live-Recording-Sektion im Day-Detail: manueller Toggle, aktueller Standort, Live-Polyline, gespeicherte Live-Tracks
- Optionen-Seite ueber das Actions-Menue: lokale Distanz-Einheit, Start-Tab, Kartenstil, Sprache, technische Importdetails und optionaler Server-Upload
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

Neu auf Code-Stand 2026-03-18:
- Google-Takeout-`location-history.json` und `.zip` werden direkt unterstuetzt
- Live-Location / Live-Recording ist eingebaut (lokal, manuell gestartet; optionaler Background-Modus im aktuellen Code)
- Live-Tracks werden getrennt von importierter History gespeichert; kein Auto-Resume nach Neustart
- Wrapper-Unit-Tests und generischer iOS-Build sind gruen; Stand 2026-03-30 laeuft auch `xcodebuild test -only-testing:LH2GPXWrapperTests` auf dem iPhone-17-Pro-Max-Simulator erfolgreich durch

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
- der Standard-Testendpunkt fuer den Server-Upload ist mit `https://178-104-51-78.sslip.io/live-location` vorbelegt
- frische Device-Verifikation fuer den erweiterten Permission-/Background-Flow ist weiter offen
- frische Device-Verifikation fuer den reaktivierten Auto-Restore-Flow ist weiter offen

Aktueller Server-Truth fuer den eingebundenen Core-Stand:
- `swift test` im Core-Repo laeuft auf diesem Linux-Server gruen mit `217` Tests, `2` Skips und `0` Failures
- der Wrapper-spezifische Xcode-/Device-Stand bleibt der zuletzt dokumentierte Apple-Lauf vom 2026-03-30; ein frischer Xcode-Rerun ist auf diesem Server nicht moeglich

Unterstuetztes Import-Format: jede `.json`-Datei oder `.zip`-Datei, die einen gueltigen LH2GPX-App-Export enthaelt, plus Google-Timeline-`location-history.json` / `.zip` aus Google Takeout.

Vollstaendiges Device-Runbook: `docs/LOCAL_IPHONE_RUNBOOK.md`

iPad: bewusst spaeter.

## TestFlight + App Store Readiness (Phase 20 – extern geparkt)

Lokal verifiziert (2026-03-17):
- `xcodebuild archive` erfolgreich (v1.0, Build 1)
- `PrivacyInfo.xcprivacy` UserDefaults-Zugriff (CA92.1) deklariert

Offen (Stand 2026-03-30):
- Privacy-Manifest-Scope fuer optionalen Server-Upload (Standortdaten) ungeklaert
- App Review Guidelines 5.1.1 (Data Collection) und 5.1.2 (Privacy Manifests): teilweise – kein abschliessender Nachweis der Konformitaet fuer den Upload-Pfad
- ein manueller Xcode-Start auf dem verbundenen iPhone bleibt ein positiver Teilbefund, ist aber bewusst getrennt von den CLI-Build-/Test-Ergebnissen zu lesen

Lokal abgeschlossen (2026-03-17):
- App Icon: Map-Pin + "LH2GPX" (kein Gradient-Placeholder mehr)
- Screenshots erstellt: `docs/appstore-screenshots/` (iPhone 17 Pro Max, iPad Pro 13")

Bewusst geparkt (ASC-Zugang erforderlich):
- App Store Connect Projekt anlegen
- Screenshots in ASC hochladen
- Upload / TestFlight-Beta

Vollstaendiger Submission-Leitfaden: `docs/TESTFLIGHT_RUNBOOK.md`

## Was bewusst noch nicht vorbereitet ist

- kein finales App-Icon-Design (Interims-Icon vorhanden, finales Branding-Design steht aus)
- keine vollstaendige Lokalisierung; derzeit partielle Deutsch/Englisch-Abdeckung aus dem Core-Repo
- keine Heatmap-Produktreife- oder Performance-Verifikation, kein Replay, keine Offline-Karten
- kein CSV-/KMZ-Export
- kein Resume laufender Live-Tracks, kein Cloud-/Sync-Flow fuer importierte History, keine frische Device-Verifikation fuer optionales Background-Live-Recording

## Roadmap

Die vollstaendige Delivery-Roadmap liegt jetzt identisch in beiden Repos:
- [ROADMAP.md](/home/sebastian/repos/LH2GPXWrapper/ROADMAP.md)
- [NEXT_STEPS.md](/home/sebastian/repos/LH2GPXWrapper/NEXT_STEPS.md)

Diese Dateien muessen zwischen Core-Repo und Wrapper-Repo inhaltlich synchron gehalten werden.
