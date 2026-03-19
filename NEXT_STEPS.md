# NEXT_STEPS

Abgeleitet aus der Roadmap. Nur die konkret naechsten offenen Schritte.

1. **Phase 19.46 – Filterung / Accuracy groundwork**
   - bestehende Export-/Insights-Daten um echte Accuracy-orientierte Filterbarkeit erweitern statt nur Filtertexte anzuzeigen
   - den Weg fuer spaetere Polygon-/Bereichsfilter vorbereiten, ohne schon eine volle Geometrie-UI aufzubauen
2. **Phase 20 / 21 – bewusst nicht jetzt**
   - keine Apple-/ASC-/TestFlight-/Release-Arbeit
3. Contract-Files weiter ausschliesslich vom Producer-Repo aus aktualisieren.
4. Spaeterer Produktwunsch: Optionen um App-Sprache erweitern (`English`, `Deutsch`), ohne das jetzt schon umzusetzen.

**Abgeschlossene Phase 19.45 (2026-03-19):**
- `ExportRouteSanitizer` bereinigt jetzt exakte aufeinanderfolgende Duplikatpunkte zentral vor Export und Vorschau
- Routen, die nach der Bereinigung unter zwei Punkte fallen, werden nicht mehr als exportierbar oder preview-faehig behandelt
- `DaySummary` fuehrt dafuer eine echte `exportablePathCount`-Sicht; Export-Readiness und Helper-Copy zaehlen jetzt dieselben Routen wie GPX/KML wirklich schreiben
- Insights-/Overview-Review-Fix: Day-Navigation aus Highlights und Insights funktioniert jetzt auch auf regular width
- 2 neue Tests plus erweiterte Query-/Export-Tests; `swift test` gruen: `171/171`

**Abgeschlossene Phase 19.44 (2026-03-19):**
- `ExportInsights`/`AppExportQueries` liefern jetzt zusaetzlich `Most Visits` und `Most Routes`
- Day-Liste und Overview zeigen diese Highlight-Tage nun sichtbar ueber weitere Icons und Karten
- Insights hat jetzt eine eigene `Active Filters`-Sektion statt Filter nur indirekt wirken zu lassen
- neuer interaktiver `Top Days`-Block rankt Tage nach `Events`, `Visits`, `Routes` oder `Distance` und springt per Tap direkt in den Tag
- `InsightsTopDaysPresentation` kapselt Ranking, Tiebreaker und Copy testbar; `DaySummary` hat dafuer jetzt einen expliziten `public init`
- 4 neue/erweiterte Tests; Volltest folgt gruener Paket-Suite

**Abgeschlossene Phase 19.43 (2026-03-19):**
- Export-Flow unterstuetzt jetzt `KML` als zweites echtes Dateiformat neben `GPX`
- `KMLBuilder` erzeugt KML-LineStrings aus denselben exportierbaren Quellen wie GPX
- FileExporter, Dateinamencopy und Fehlertexte folgen jetzt dem ausgewaehlten Format
- bestehende Export-Selektion und Vorschau bleiben formatuebergreifend gleich
- 3 neue Tests; `swift test` gruen: `164/164`

**Abgeschlossene Phase 19.42 (2026-03-19):**
- Export-Screen zeigt jetzt eine `Route Preview`-Karte vor der eigentlichen Quellenliste
- die Vorschau nutzt nur wirklich exportierbare Routen-Geometrie aus importierten Tagen und Saved Tracks
- leere und route-lose Selektionen erklaeren explizit, warum noch keine Karte erscheint
- `ExportPreviewDataBuilder` kapselt Overlay-/Region-Logik testbar
- 2 neue Tests; `swift test` gruen: `161/161`

**Abgeschlossene Phase 19.41 (2026-03-19):**
- Export unterstuetzt jetzt neben importierten Tagen auch `Saved Tracks` als echte zweite Quelle
- Export-Screen zeigt getrennte Auswahlbereiche fuer `Imported Days` und `Saved Tracks`
- gemischte Selektionen aus Tagen und Saved Tracks werden in Readiness, Helper-Copy und Dateinamenerwartung gemeinsam gefuehrt
- gespeicherte Live-Tracks werden fuer GPX kontrolliert in exportierbare `Day`/`Path`-Strukturen ueberfuehrt
- 4 neue Tests; `swift test` gruen: `159/159`

**Abgeschlossene Phase 19.40 (2026-03-19):**
- schneller Re-Select des compact `Days`-Tabs oeffnet jetzt den relevanten aktuellen Tag statt am aeltesten Listenkontext haengen zu bleiben
- Re-Select leert aktive Suche, setzt den compact Navigation-Stack zurueck und springt direkt in den Zieltag
- Zieltag-Logik bevorzugt `heute`, sonst den letzten vergangenen contentful day, sonst den ersten zukuenftigen contentful day
- no-content-Tage werden in diesem Sprungpfad weiter als Dead End vermieden
- 2 neue Tests; `swift test` gruen: `157/157`

**Abgeschlossene Phase 19.39 (2026-03-19):**
- Day-Suche nutzt jetzt auf compact und regular dieselbe zentrale Filterlogik
- regular-width `Days` zeigt bei `0` Suchtreffern denselben Search-Empty-State wie compact statt `No Days`
- Blank-Queries werden explizit als inaktive Suche behandelt
- `Optionen`, `Export` und `Saved Tracks` werden ueber stabile globale Sheets praesentiert statt ueber fragilen Menu-Sheet-Aufbau
- 1 neuer Test; `swift test` gruen: `155/155`

**Abgeschlossene Phase 19.34 (2026-03-19):**
- Day-Liste zeigt jetzt einen expliziten Export-Statusblock statt die GPX-Selektion nur ueber kleine Row-Icons anzudeuten
- compact und regular Layout spiegeln dieselbe Export-Selektion konsistent im Listenkontext
- Export-markierte Tage tragen jetzt ein klares `Export`-Badge statt nur ein kleines Symbol
- Such-Empty-State erklaert jetzt auch, wenn bereits markierte Export-Tage nach dem Leeren der Suche weiter vorhanden bleiben

**Abgeschlossene Phase 19.33 (2026-03-19):**
- Overview fuehrt jetzt wieder mit Import-Status und aktiven Export-Filtern statt lokale Tools frueh zu vermischen
- kompakter `Go To`-Block auf iPhone macht `Days`, `Insights` und `Export` als Primaerpfade direkt in der Overview sichtbar
- Statistik-Sektion rahmt sich explizit als `Imported History` statt als generische Zahlenwand
- `Saved Tracks` ist jetzt als eigener `Local Tools`-Block nach hinten gestellt und optisch weniger dominant

**Abgeschlossene Phase 19.32 (2026-03-19):**
- Insights-Tab zeigt jetzt einen echten Top-Level-Empty-State, wenn ein Export gar keine Tage enthaelt
- sparse Exporte mit nur einem sehr duennen Tag erklaeren jetzt, warum vergleichende Insights noch begrenzt sind
- `Daily Averages`, `Activity Types`, `Visit Types` und `Period Breakdown` verschwinden bei fehlenden Daten nicht mehr still, sondern zeigen den konkreten Grund
- `InsightsChartSupport` kapselt Overview- und Section-Empty-State-Copy testbar

**Abgeschlossene Phase 19.38 (2026-03-19):**
- Export-Screen zeigt jetzt einen expliziten Auswahl-/Readiness-Status statt nur eine nackte Day-Liste
- Disabled-Zustaende des Export-Buttons nennen den konkreten Grund: keine Auswahl oder keine Routen
- Dateinamenerwartung wird vor dem Export als `Suggested filename` sichtbar gemacht
- gemischte Selektionen erklaeren, wenn nur ein Teil der gewaehlten Tage wirklich GPX-Routen beisteuert
- `ExportPresentation` kapselt Readiness-, Button- und Filename-Copy testbar

**Abgeschlossene Phase 19.37 (2026-03-19):**
- Distance- und Weekday-Charts zeigen jetzt chart-spezifische Low-Data-States statt still zu verschwinden
- Distance-Chart erklaert Tap-Navigation und loest Taps robuster auf den naechsten vorhandenen Tag auf
- Activity- und Visit-Charts zeigen wieder lesbare Achsen; Activity-Metric-Umschalter erscheint nur noch wenn Distanzdaten wirklich vorhanden sind
- zentrale `InsightsChartSupport`-Logik deckt Low-Data-Messages, Metrikverfuegbarkeit und Day-Tap-Aufloesung testbar ab

**Abgeschlossene Phase 19.36 (2026-03-19):**
- Saved-Tracks-Zugang heisst jetzt in Overview, Library und Empty States konsistent `Saved Tracks`
- `Edit Track` bleibt auf den eigentlichen Bearbeitungsschritt begrenzt statt schon den Bibliothekszugang zu benennen
- Iconographie und Copy trennen Library-Zugang klarer von importierter History und vom Editor
- zentrale `SavedTracksPresentation`-Texte machen die Benennung test- und wiederverwendbar

**Abgeschlossene Phase 19.35 (2026-03-19):**
- Day-Detail gliedert importierte Tageshistorie jetzt explizit in Summary, Kartenkontext, Timeline und Daten-Sektionen
- Live Recording und Saved-Track-Werkzeuge erscheinen erst danach als klar sekundaerer lokaler Block
- testbare Hierarchie-/Time-Range-Hilfslogik deckt Reihenfolge und Zeitspannen der Day-Detail-Inhalte ab

**Abgeschlossene Phase 19.31 (2026-03-19):**
- `DaySummary.hasContent` ergaenzt und Query-Layer auf repo-wahre no-content-Tage gehaertet
- initiale Tagesauswahl bevorzugt jetzt contentful days statt blindem first-day-Verhalten
- compact/regular `Days` oeffnen no-content-Tage nicht mehr als normale Detailziele
- regular detail zeigt einen klaren Rueckweg zur `Overview`
- Export-Badge in gruppierter und ungruppierter Day-Liste jetzt konsistent
- 2 neue Session-State-Tests plus Query-Assertions; `swift test` wieder gruen

**Abgeschlossene Phase 19.30 (2026-03-18):**
- LiveLocationFeatureModel + SystemLiveLocationClient fuer foreground-only While-In-Use-Tracking
- LiveTrackRecorder mit Accuracy-/Dedupe-/Mindestdistanz-/Flood-Logik
- AppLiveLocationSection im Day-Detail: Toggle, Permission-State, aktueller Standort, Live-Polyline
- RecordedTrackFileStore: getrennte Persistenz abgeschlossener Live-Tracks, save on stop, kein Auto-Resume
- Wrapper-Info.plist: NSLocationWhenInUseUsageDescription
- 13 neue Tests; 125/125 gruen

**Abgeschlossene Phase 19.29 (2026-03-18):**
- GPXBuilder: Path.points → GPX 1.1 Tracks, XML-Escaping, Dateinamen-Helfer
- ExportSelectionState: value-type Set<String>, in AppSessionState eingebettet (app-weit)
- GPXDocument: FileDocument fuer fileExporter-Flow
- AppExportView: 4. Tab (iPhone) + Sheet (iPad), Checkboxen, Select All, Export-Button
- ExportFormat Enum: GPX aktiv, KML/CSV-Architektur vorbereitet
- AppDayRow: Export-Badge wenn Tag selektiert
- 16 neue Tests; 112/112 gruen

**Abgeschlossene Phase 19.28 (2026-03-19):**
- neue `AppPreferences`-Domain fuer echte lokale Optionen
- Optionen-Seite ueber Actions-Menue in Core-App und Wrapper erreichbar
- Distanz-Einheit, Start-Tab, Kartenstil und technische Importdetails app-weit steuerbar
- bewusst keine Cloud-/Server-/Sync-Toggles
- 4 neue Tests; 135/135 gruen

**Abgeschlossene Phasen 19.23–19.27 (2026-03-18):**
- 19.27: DemoSupport-Typealiases entfernt, Public-API-Docs, Dead Code entfernt
- 19.26: God-File Split (AppContentSplitView 1677->444 Zeilen, 6 neue Dateien)
- 19.25: "Paths"->"Routes", Daily Averages Guard, Activity-Breakdown-Farben
- 19.24: Accessibility (VoiceOver, coloredCard, iOS-16 Fallback, Empty States)
- 19.23: CI/CD, SwiftLint, ZIPFoundation-Pin, onChange-Fix, Wrapper-Tests
