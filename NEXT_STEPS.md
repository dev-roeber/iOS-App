# NEXT_STEPS

Abgeleitet aus der Roadmap. Nur die konkret naechsten offenen Schritte.

Aktuell gibt es keine weiteren aktiven lokalen 19.x-Implementierungsschritte mehr.

Die naechsten dokumentierten Themen liegen ausserhalb des aktuellen lokalen UI-/UX-Scopes:

1. **Phase 20 – Apple / ASC / TestFlight / externe Distribution**
   - bleibt bewusst geparkt und braucht Apple-Hardware, Signierungskontext und reale Distribution statt Linux-Repo-Arbeit
2. **Apple-Verifikation auf Hardware**
   - `Product > Run`, Live-Location-Permission-Flow sowie reale Device-Checks fuer `location-history.json/.zip` bleiben weiterhin ausserhalb dieses Hosts offen
3. **Phase 21 – spaetere Folgearbeit**
   - weiterhin bewusst unberuehrt; kein unmittelbarer naechster lokaler Implementierungsschritt

Contract-Files werden weiterhin ausschliesslich vom Producer-Repo aus aktualisiert.

**Abgeschlossene Phase 19.38 (2026-03-20):**
- Export zeigt jetzt Auswahlzusammenfassung, Dateinamenvorschau und explizite Disabled-Reasons
- Tage ohne GPX-faehige Routen werden deutlicher markiert
- ausgewaehlte Tage sind in der Export-Liste visuell klarer hervorgehoben

**Abgeschlossene Phase 19.37 (2026-03-20):**
- Charts zeigen explizitere Achsen, Wertehinweise und erklaerende UI-Hinweise fuer vorhandene Insights
- Distance-Chart erklaert die Tap-Navigation in den Day-Detail-Kontext
- keine neuen Statistiken, sondern bessere Lesbarkeit der bestehenden Visualisierungen

**Abgeschlossene Phase 19.36 (2026-03-20):**
- Saved-Live-Track-Wording ueber Overview, Day Detail, Library, Sheet-Fallback und Editor vereinheitlicht
- lokaler Track-Library-/Bearbeitungsfluss ist deutlicher von importierter History getrennt
- `Edit Saved Track` benennt den Editor jetzt konkret und konsistent

**Abgeschlossene Phase 19.35 (2026-03-20):**
- Quick-Stats, Karte, Timeline und importierte Sections im Day Detail klarer als importierte Tagesdaten gerahmt
- `Local Recording` als separater Kontextblock unterhalb der importierten Inhalte eingeordnet
- Live Recording bleibt funktional unveraendert, steht aber nicht mehr mitten im importierten Primarfluss

**Abgeschlossene Phase 19.34 (2026-03-20):**
- Day Rows zeigen Export-Selektion jetzt mit deutlicherem Badge und subtiler Hervorhebung
- compact und regular `Days` zeigen bei aktiver Selektion einen sichtbaren Export-Kontext mit direktem Einstieg in den Export-Flow
- Such-, Leer- und Exportzustand ueberlagern sich nicht mehr so unklar wie zuvor

**Abgeschlossene Phase 19.33 (2026-03-20):**
- Overview startet jetzt mit Status und einer eigenen `Primary Actions`-Sektion
- direkte Einstiege in `Open`, `Browse Days`, `Open Insights` und `Export GPX`
- Track-Library-/Track-Editor-Einstieg bleibt vorhanden, ist aber klar sekundar eingeordnet

**Abgeschlossene Phase 19.32 (2026-03-20):**
- Insights zeigen explizite Empty States fuer no-days-, low-data- und no-chart-Faelle
- fehlende Distanz-, Activity-, Visit-, Weekday- und Period-Daten werden erklaert statt still ausgeblendet
- duenne, aber gueltige Imports zeigen einen sichtbaren `Limited Insight Data`-Hinweis

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
