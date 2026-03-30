# CHANGELOG

## 2026-03-30

### Heatmap Fine Detail / Zoom Tuning Batch 4

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: LOD-Grid-Schritte fuer mittlere und hohe Zoom-Stufen verfeinert (medium: 0.018→0.012, high: 0.004→0.003) — weniger blockartige Grossflaechen, mehr Granularitaet bei Feinzoom
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: LOD-Umschaltschwellen frueher gesetzt (low→medium bei spanDelta>1.4 statt >1.6; medium→high bei >0.12 statt >0.16) — feinere Darstellung setzt bei weiterer Herausgezoomtheit ein
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: selectionLimit fuer medium (132→160) und high (220→280) angehoben — mehr sichtbare Zellen bei Feinzoom ohne macro-Limit zu beruehren
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: minimumNormalizedIntensity fuer low (0.06→0.04), medium (0.035→0.025) und high (0.02→0.015) gesenkt — schwache Dichtebereiche bleiben sichtbar und fallen nicht weg
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: displayIntensity-Kurve angepasst (Exponent 0.58 statt 0.72) — untere Intensitaetsstufen werden sichtbarer angehoben ohne Rauschen zu dominieren
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: effectiveOpacity-Emphasis-Basis leicht angehoben (0.82 statt 0.72) und Mindestopacity auf 0.06 gesetzt — niedrige Dichte bleibt dezent sichtbar statt zu verschwinden
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Farbpalette geschaerft: kuehles Blau minimal saettiger, Cyan/Gruen-Mitte ausgepraegterer Charakter, Orange/Rot-Hochbereich kraftvoller und sauberer; Legende an neue Palette angeglichen

### Heatmap Color / Contrast / Opacity Batch 3

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Heatmap-Farb- und Deckkraftwirkung deutlich verstaerkt, ohne den Polygon-/LOD-/Viewport-Renderer aus Batch 2 zurueckzubauen; 100 % im Deckkraft-Slider mappt jetzt ueber eine nichtlineare Kennlinie auf sichtbar vollere Darstellung
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Intensitaets-Mapping fuer mittlere und hohe Dichten angehoben, damit Hotspots staerker tragen und mittlere Dichte nicht zu stark absauft
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Farbskala von groben Stufen auf weich interpolierte Gradient-Stops mit staerkerem Warmbereich fuer hohe Dichte umgestellt; Legende an dieselbe Palette angeglichen
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: kleine Logiktests fuer Intensitaets-Lift, High-End-Opacity-Mapping und waermer werdende Palette hinzugefuegt
- `README.md`, `ROADMAP.md`, `NEXT_STEPS.md`, `docs/APP_FEATURE_INVENTORY.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`: Batch-3-Farb-/Kontrast-Update und der weiterhin offene Apple-Device-Nachweis repo-wahr nachgezogen

### Heatmap Visual & Performance Batch 2

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Heatmap-Renderer von sichtbar ueberlappenden Kreis-Stempeln auf geglaettete, aggregierte Polygon-Zellen umgestellt; LOD-abhaengige Zellgroessen, ruhigere Farb-/Deckkraftabstufung und weniger flaechiges Uebermalen bei mittleren/grossen Zoomstufen
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: viewport-basierte Zellselektion mit per-LOD gecappten sichtbaren Elementen und wiederverwendbarem Viewport-Cache eingebaut, um Renderlast und Rebuilds beim Zoomen/Pannen zu reduzieren
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: vorhandene Heatmap-Controls aus Batch 1 beibehalten und den Radius-Preset an den neuen Polygon-Renderer angebunden, damit die Darstellung weiter direkt steuerbar bleibt
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: kleine Render-/LOD-Regressionstests fuer grobere Aggregation und viewport-/limit-respektierende Zellselektion hinzugefuegt
- `README.md`, `ROADMAP.md`, `NEXT_STEPS.md`, `docs/APP_FEATURE_INVENTORY.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`: Heatmap-Rendering-/Performance-Strategie und der weiterhin offene Apple-Device-Nachweis repo-wahr nachgezogen

### Heatmap UX Batch 1

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Heatmap-Darstellung auf mittleren und grossen Zoomstufen sichtbar entschärft; LOD-abhaengige Radius-/Deckkraft-Abstufung, weniger dominante Flaechenwirkung und `fit-to-data`-Startzustand aus den vorhandenen Punktgrenzen
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: kleines Bottom-Control-Panel mit Deckkraft-Regler, Radius-Presets, `Auf Daten zoomen` und unaufdringlicher Dichte-Legende hinzugefuegt; Header bleibt ueber die Sheet-Navigation kompakter
- `Sources/LocationHistoryConsumerAppSupport/AppLanguageSupport.swift`: neue Heatmap-UX-Strings fuer Deutsch/Englisch ergaenzt
- `README.md`, `ROADMAP.md`, `NEXT_STEPS.md`, `docs/APP_FEATURE_INVENTORY.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`: Heatmap-UX-Umfang repo-wahr nachgezogen, ohne den noch offenen Apple-Device-Nachweis des Sheets als erledigt zu markieren

### Apple Device Verification Batch 1

- `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`, `NEXT_STEPS.md`: echter iPhone-15-Pro-Max-Lauf (iOS 26.3) repo-wahr nachgezogen
- reale Wrapper-UI-Automation auf dem verbundenen iPhone per `xcodebuild test -allowProvisioningUpdates` erneut belegt
- `LH2GPXWrapperUITestsLaunchTests.testLaunch` lief auf dem echten iPhone erfolgreich durch; der Wrapper startet auf aktueller Hardware stabil
- der fehlgeschlagene Screenshot-Test lieferte einen verwertbaren Device-Befund statt eines leeren Infra-Fehlers: beim Start war bereits eine importierte `location-history.zip` wiederhergestellt, `Heatmap` war als Aktion sichtbar und der dedizierte `Live`-Tab lag in der Tab-Bar vor
- Background-Recording, aktives Oeffnen des Heatmap-Sheets, aktive `Live`-Tab-Interaktion und End-to-End-Upload bleiben trotz dieser Teilbefunde offen

### Apple Stabilization Batch 2

- `Tests/LocationHistoryConsumerTests/AppPreferencesTests.swift`: Test-Setup an Apple-Realitaet angeglichen – Bearer-Token wird fuer `testStoredValuesAreLoaded` ueber den Keychain-Pfad gesetzt; Keychain wird in `setUp`/`tearDown` explizit bereinigt
- `Tests/LocationHistoryConsumerTests/DayDetailPresentationTests.swift`: Erwartung fuer `timeRange` auf den im Produktcode konsistent verwendeten Gedankenstrich `" – "` angepasst
- `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`, `NEXT_STEPS.md`, `README.md`, `ROADMAP.md`: Apple-CLI-Stand nach erneuter Verifikation auf gruen nachgezogen; offene Device-End-to-End-Themen bewusst offen gelassen

### Apple Stabilization Batch 1

- `AppOptionsView.swift`: `.textInputAutocapitalization(.never)` in `#if os(iOS)`-Guard eingeschlossen – iOS-only API war auf macOS ein Compile-Fehler
- `AppContentSplitView.swift`: `if #available(iOS 17.0, macOS 14.0, *)` statt `if #available(iOS 17.0, *)` fuer `AppLiveTrackingView` – fehlender macOS-Teil verhinderte macOS-Build
- `AppDayDetailView.swift`: `if #available(iOS 17.0, macOS 14.0, *)` statt `if #available(iOS 17.0, *)` fuer `AppLiveLocationSection` – gleiche Ursache
- `Sources/LocationHistoryConsumerDemo/RootView.swift`: `loadImportedFile(at:)` als `async` markiert und mit `Task { await ... }` aufgerufen – fehlte nach async-Aenderung in `DemoDataLoader.loadImportedContent`
- `Sources/LocationHistoryConsumerApp/AppShellRootView.swift`: analog zu RootView.swift – `loadImportedFile(at:)` async gemacht und Aufruf per `Task { await ... }` korrigiert
- `LiveLocationFeatureModelTests.swift`: `minimumBatchSize: 1` explizit in Upload-Test-Konfiguration gesetzt – Default ist 5, Tests prueften 1-Punkt-Upload (Test-Drift, kein Produktfehler)
- `LiveLocationFeatureModelTests.swift`: `testBackgroundPreferenceActivatesClientWhenAlwaysAuthorized` auf korrektes Produktverhalten angepasst – Client-Background-Konfiguration wird erst beim Recording-Start gesetzt, nicht bei blosser Preference-Aenderung (Test-Drift)
- `docs/APPLE_VERIFICATION_CHECKLIST.md`: ehrlicher Stand nach Apple Stabilization Batch 1 dokumentiert – CLI-Build/Test-Ergebnisse eingetragen, Einschraenkungen klar benannt
- `README.md`: "offline-only" in Beschreibung der App-Shell auf "offline-first, optionaler Upload" korrigiert – interner Widerspruch behoben
- README, ROADMAP, NEXT_STEPS und Xcode-Runbooks nach erneutem Apple-CLI-Rerun nachgeschaerft – Wrapper-Simulator-Tests als gruen eingetragen, die 2 verbleibenden roten macOS-/SwiftPM-Tests explizit offengelassen statt als "plattformbedingt" zu markieren

### Heatmap Compiler- und Diagnostik-Fixes
- `AppHeatmapView.body` in `mapView`- und `calculatingOverlay`-`@ViewBuilder`-Properties aufgeteilt, um Compiler-Timeout zu beheben
- `.blendMode(.plusLighter)` von `ForEach` (MapContent) auf den `Map`-View selbst verschoben
- `CLLocationCoordinate2D: @retroactive Equatable`-Extension ergaenzt, damit `.onChange(of: model.initialCenter)` kompiliert

### Audit Fix / Roadmap Granularization
- Audit `audits/AUDIT_LH2GPX_2026-03-30_09-11.md` gesichert und gegen den aktuellen Repo-Stand abgeglichen
- README, ROADMAP, NEXT_STEPS, Feature-Inventar und Apple-Runbooks auf Heatmap, `Live`-Tab, Upload-Batching, Wrapper-Auto-Restore und ehrlichen Teststatus synchronisiert
- stray-Dateien `lazygit` und `lazygit.tar.gz` aus dem Core-Repo entfernt und in `.gitignore` aufgenommen

## 2026-03-20

### Heatmap / Live Tab / Upload Batching
- `AppHeatmapView` als eigenes Heatmap-Sheet fuer importierte History auf iOS 17+/macOS 14+ eingebaut
- compact iPhone-Layout erhielt einen dedizierten `Live`-Tab fuer Live-Location und Live-Recording auf iOS 17+
- `AppPreferences` und Live-Upload-Konfiguration unterstuetzen jetzt Upload-Batching (`Every Point`, `Every 5 Points`, `Every 15 Points`, `Every 30 Points`)

### Navigation / Search / Sheet Stability
- `Days`-Suche funktioniert jetzt in compact und regular width und matcht nicht nur ISO-Datum, sondern auch formatiertes Datum, Wochentag und Monat
- iPhone-`Days` reagiert auf erneutes Tab-Selektieren, setzt Suche/Navigationspfad zurueck und springt auf den aktuellen Tag, wenn dieser im Import vorhanden ist
- `AppContentSplitView` nutzt jetzt einen einzigen Sheet-Praesentationszustand fuer Export, Optionen und Saved-Live-Track-Library statt konkurrierender `.sheet`-Ketten am Actions-Menue

### Saved Live Tracks / Local Recording
- Saved-Live-Track-Wording ueber Overview, Day Detail, Library, Sheet-Fallback und Editor vereinheitlicht
- gespeicherte Live-Tracks werden klarer als lokaler Nebenfluss ausserhalb importierter History bezeichnet
- Track-Editor-Titel benennt jetzt konkret das Bearbeiten eines gespeicherten Tracks
- Overview-Primary-Actions, Actions-Menue und Day Detail fuehren jetzt direkt in dieselbe dedizierte `Saved Live Tracks`-Library
- der Live-Recording-Bereich zeigt keinen zweiten halben Library-Flow mehr, sondern verweist gezielt auf die separate Library-Seite
- die Library-Seite selbst zeigt jetzt auch Zusammenfassung und neuesten gespeicherten Track als eigenen lokalen Arbeitsbereich
- Live-Recording hat jetzt echte Optionen fuer Accuracy-Filter und Recording-Detail statt harter Recorder-Defaults
- `AppPreferences` steuern jetzt die Recorder-Konfiguration fuer akzeptierte Genauigkeit, Mindestbewegung und Zeitabstand zwischen Punkten
- geaenderte Live-Recording-Optionen wirken direkt auf den lokalen Recorder-Flow
- Background-Recording kann jetzt lokal in den Optionen aktiviert werden und fordert bei While-In-Use eine `Always Allow`-Erweiterung an
- der Core-iOS-Client kann echte Background-Location-Updates aktivieren, wenn `authorizedAlways` vorhanden ist
- gespeicherte Live-Tracks markieren jetzt auch ihren Capture-Mode fuer Foreground-vs-Background-Aufnahmen
- Live-Recording kann akzeptierte Punkte jetzt optional an einen frei konfigurierbaren HTTP(S)-Server schicken
- der Server-Upload ist nutzerseitig ein-/ausschaltbar, akzeptiert Bearer-Token und nutzt eine Retry-on-next-sample-Strategie bei Fehlern
- der Standard-Testendpunkt ist mit `https://178-104-51-78.sslip.io/live-location` vorbelegt und damit konsistent zur HTTPS-Validierung des Codes
- der Live-Recording-Bereich zeigt jetzt auch einen sichtbaren Upload-Status, wenn der Server-Upload aktiv ist

### Sprache / Lokalisierung
- Optionen bieten jetzt eine Sprachwahl zwischen Englisch und Deutsch
- Shell-, Optionen-, Live-Recording-, Import-Entry- und zentrale Export-Oberflaechen reagieren jetzt auf die Sprachwahl
- Day List, Day Detail, Statuskarten, Saved-Live-Track-Library/-Editor, Karten-Hinweise und grosse Teile von Insights/Export reagieren jetzt ebenfalls auf die Sprachwahl
- noch nicht uebersetzte Strings fallen bewusst auf Englisch zurueck, statt fehlerhafte Platzhalter zu zeigen

### Insights / Empty-State Hardening
- Insights zeigen jetzt explizite Fallbacks fuer no-days-, low-data- und chart-unverfuegbare Faelle statt halbleerer Flaechen
- fehlende Distanz-, Activity-, Visit-, Weekday- und Period-Daten werden pro Sektion erklaert
- Imports mit sehr duennen, aber gueltigen Daten zeigen einen sichtbaren `Limited Insight Data`-Hinweis

### Charts / Export Polish
- Distance-, Activity-, Visit- und Weekday-Charts zeigen explizitere Achsen, Wertehinweise und Erklaertexte
- Export zeigt Auswahlzusammenfassung, Dateinamenvorschau und explizite Disabled-Reasons direkt im Flow
- Tage ohne GPX-faehige Routen werden in der Export-Liste klarer markiert und ausgewaehlte Zeilen deutlicher hervorgehoben
- gespeicherte Live-Tracks koennen jetzt direkt in derselben Exportseite mit ausgewaehlt und als GPX zusammen mit importierten Tagen exportiert werden
- die vorhandene Export-Vorschaukarte ist jetzt im sichtbaren Export-Flow verdrahtet und zeigt die aktuelle Auswahl mit Routen-, Distanz- und Legendenzusammenfassung
- `KML` ist jetzt neben `GPX` als aktives Exportformat in der UI freigeschaltet
- lokale Export-Filter fuer `From`, `To` und `Max accuracy` wirken jetzt sichtbar auf importierte History, Vorschau und den eigentlichen Export
- lokale Export-Filter greifen bewusst nicht auf gespeicherte Live-Tracks durch und raeumen ausgeblendete Tagesselektionen aus dem Exportzustand
- lokale Export-Filter bieten jetzt auch explizite `Has ...`- und `Activity type`-Auswahl fuer importierte History statt nur still vorhandenen Query-Unterbau
- lokale Export-Filter haben jetzt auch eine echte Bounding-Box-/Polygon-UI fuer importierte History; Upstream- und lokale Flaechenfilter werden konservativ kombiniert
- Export-Vorschaukarte zeigt jetzt auch Waypoint-only-Auswahlen statt nur Routen
- `GeoJSON` ist jetzt als drittes aktives Exportformat freigeschaltet
- Export kennt jetzt die Modi `Tracks`, `Waypoints` und `Both`
- Waypoint-Export nutzt importierte Visits sowie Activity-Start/-End-Koordinaten
- Dateiname, Disabled-Reasons und Hilfetexte reagieren jetzt auf den aktiven Exportmodus statt still route-only zu bleiben

### Overview / Days / Day Detail Polish
- Overview startet jetzt mit Status und einer `Primary Actions`-Sektion fuer Open, Days, Insights und Export
- Export-Selektion ist in der Day-Liste sichtbarer und fuehrt ueber einen expliziten Export-Kontext schneller in den Export-Flow
- Day Detail trennt importierte Tagesdaten klarer von lokalem Live Recording und gespeicherten Live-Tracks

## 2026-03-19

### Navigation / Dead-End Hardening
- no-content-Tage bleiben in der Day-Liste sichtbar, werden aber in compact und regular nicht mehr wie normale Detailziele behandelt
- initiale Tagesauswahl bevorzugt jetzt contentful days statt blind den ersten Kalendertag
- Export-Badge in gruppierter und ungruppierter Day-Liste vereinheitlicht

### Lokale Optionen / Produktsteuerung
- lokale Optionen-Seite fuer Distanz-Einheit, Start-Tab, Kartenstil und technische Importdetails eingebaut
- `AppPreferences` als zentrale `UserDefaults`-Domain fuer Core-App und Wrapper verdrahtet
- Distanz-/Speed-Formatierung, Kartenstil, Start-Tab und technische Metadaten folgen denselben Preferences

### Repo-Truth / Dokumentation
- repo-wahres Feature-Inventar ergaenzt und 19.x-Roadmap auf aktuelle lokale Priorisierung bereinigt
- README, ROADMAP und NEXT_STEPS auf den tatsaechlichen Stand von Optionen, Day-Navigation und offenem Fokus synchronisiert

## 2026-03-18

### Export / Recorded Tracks
- GPX-Export mit app-weiter Tagesselektion, Export-Tab/-Sheet und Dateinamenvorschlag eingebaut
- Recorded-Track-Library und Track-Editor fuer gespeicherte Live-Tracks eingefuehrt
- Track-Editor-Zugang in Overview und Live-Recording-Bereich auffindbarer gemacht

### Import Truth Sync
- verbliebene Core-UI-Texte von `app_export`-Spezialfall auf den echten JSON-/ZIP-Import-Scope umgestellt
- ZIP-Fehlermeldungen auf aktuelle Unterstuetzung fuer LH2GPX- und Google-Timeline-Archive korrigiert
- `AGENTS.md`, README und Apple-/Xcode-Doku auf den realen Importstand synchronisiert

### Live Recording MVP
- foreground-only Live-Location fuer die Kartenansicht eingebaut
- manuellen Ein/Aus-Schalter mit sauber modellierten Permission-Zustaenden hinzugefuegt
- Live-Track mit Accuracy-/Dedupe-/Mindestdistanz-Filtern und Polyline-Rendering umgesetzt
- abgeschlossene Live-Tracks getrennt von importierter History in einem dedizierten Store persistiert
- bewusst offen gelassen: Background-Tracking, Auto-Resume von Drafts, Export aufgezeichneter Live-Tracks
