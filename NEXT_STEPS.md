# NEXT_STEPS

Abgeleitet aus der Roadmap. Nur die konkret naechsten offenen Schritte.

1. **Lokale Produktweiterentwicklung (aktiver Fokus)** – Phase 19.21b abgeschlossen (Google Timeline JSON direkt importierbar). Kein konkret naechster Schritt definiert.
2. **Phase 20 / Phase 21 – bewusst geparkt** – Erfordert Apple Developer Account / ASC-Zugang. Kein aktiver Fokus.
3. **Accessibility-Audit – bewusst geparkt** – Kein konkreter Bug, kein Trigger. Kein aktiver Fokus.
4. Contract-Files weiter ausschliesslich vom Producer-Repo aus aktualisieren.

**Abgeschlossene Phase 19.21b (2026-03-18):**
- Google Timeline JSON direkt importierbar (ohne ZIP); hasValidEntry-Guard fuer leere Arrays
- 2 neue Tests; 96/96 gruen

**Abgeschlossene Phase 19.21 (2026-03-18):**
- Google Takeout ZIP direkt importierbar: GoogleTimelineConverter (visit/activity/timelinePath)
- distanceMeters String/Double; ISO8601 mit Zeitzonenoffsets; hasValidEntry-Guard
- 6 neue Tests; 94/94 gruen

**Abgeschlossene Phase 19.20 (2026-03-18):**
- ZIP-Import dateiname-agnostisch: jede .json im ZIP wird geprueft
- Neuer Error multipleExportsInZip; jsonNotFoundInZip-Text ohne Namens-Pflicht
- 7 neue Tests; 88/88 gruen

**Abgeschlossene Phase 19.18 (2026-03-18):**
- compactDayList immer mit List als Root; No-Results + Empty als .overlay
- Schwarz-Bug im Dark Mode behoben; 81/81 Tests gruen

**Abgeschlossene Phase 19.17 (2026-03-18):**
- userFacingTitle pro Error-Case in AppContentLoaderError
- actionable errorDescription fuer alle Cases, inkl. Konvertierungs-Workflow bei jsonNotFoundInZip
- loadImportedFile in ContentView.swift + AppShellRootView.swift nutzt userFacingTitle
- emptyStateView-Text verbessert (beide Views)
- 5 neue Tests; 81/81 gruen

**Abgeschlossene Phase 19.16 (2026-03-18, real fix 2026-03-18):**
- ZIP-Import: ZipFoundation 0.9.19+, erkennt app_export.json in Root + Unterverzeichnissen
- ContentView.swift (Wrapper) korrigiert: fileImporter hatte nur [.json], ZIP war ausgegraut
- 6 neue Tests fuer ZIP-Pfade (success + alle Error-Faelle), 76/76 gruen

**Abgeschlossene Phase 19.15 (2026-03-18):**
- Day-Detail-Timeline: Gantt-Zeitleiste (Visits blau, Activities gruen) mit GeometryReader
- Overview-Stat-Cards: Days → Days-Tab, Visits/Activities/Paths → Insights-Tab (nur iPhone)

**Abgeschlossene Phase 19.14 (2026-03-18):**
- Days-Tab: Suchfeld + Highlight-Markierungen (Busiest/Longest-Tage)
- Insights: Wochentags-Chart, Count/Distance-Toggle, temporale Distanz-Achse, bessere Dark-Mode-Farben
- Map: Style-Toggle (Standard/Hybrid) + farbige Visit-Marker nach Typ

**Abgeschlossene Phase 19.13 (2026-03-18):**
- Insights: 3 Swift Charts (Distanz/Tag, Activity-Types, Visit-Types)
- Tappbare Highlight-Cards mit Tab-Navigation zu Day Detail
- AppSourceSummaryCard: DisclosureGroup fuer technische Details
- Path Cards: Activity-Type-Icon
- Map-Polylines: farblich nach Activity-Type

**Abgeschlossene Phase 19.12 (2026-03-18):**
- Overview: Highlights (Busiest Day, Longest Distance Day), Filter-Transparenz-Banner
- Overview: SourceSummaryCard nach unten, Activity Types Comma-Text entfernt
- Day Detail: Tagesdistanz, Tageszeitraum, semantische Visit-/Activity-Icons
- Insights: Period Breakdown farbkodiert
- ExportInsights um busiestDay, longestDistanceDay, activeFilterDescriptions erweitert

**Abgeschlossene Phase 19.11 (2026-03-18):**
- Neuer Insights-Tab mit Activity Types, Visit Types, Daily Averages, Period Breakdown
- ExportInsights Query-Layer: stats.activities + stats.periods + Day-Daten-Fallback
- Overview erweitert: Datumsbereich-Header + Total Distance

**Lokaler iPhone-Betrieb: vollstaendig verifiziert (2026-03-17)** – iPhone 15 Pro Max und iPhone 12 Pro Max. iPad bewusst spaeter.
