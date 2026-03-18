# NEXT_STEPS

Abgeleitet aus der Roadmap. Nur die konkret naechsten offenen Schritte.

1. **Lokale Produktweiterentwicklung (aktiver Fokus)** – Phase 19.16 abgeschlossen. Naechster Schritt: Accessibility-Audit (VoiceOver, Dynamic Type) oder weiteres Feature bestimmen.
2. **Phase 20 / Phase 21 – bewusst geparkt** – Erfordert Apple Developer Account / ASC-Zugang. Kein aktiver Fokus.
3. Contract-Files weiter ausschliesslich vom Producer-Repo aus aktualisieren.

**Abgeschlossene Phase 19.16 (2026-03-18):**
- ZIP-Import: ZipFoundation 0.9.19+, erkennt app_export.json in Root + Unterverzeichnissen
- fileImporter akzeptiert .json und .zip; Labels aktualisiert

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
