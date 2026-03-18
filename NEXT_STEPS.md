# NEXT_STEPS

Abgeleitet aus der Roadmap. Nur die konkret naechsten offenen Schritte.

1. **Lokale Produktweiterentwicklung (aktiver Fokus)** – Phase 19.27 abgeschlossen (Hygiene/Docs). Kein konkret naechster Schritt definiert.
2. **Phase 20 / Phase 21 – bewusst geparkt** – Erfordert Apple Developer Account / ASC-Zugang. Kein aktiver Fokus.
3. **Accessibility-Audit – bewusst geparkt** – Kein konkreter Bug, kein Trigger. Kein aktiver Fokus.
4. Contract-Files weiter ausschliesslich vom Producer-Repo aus aktualisieren.

**Abgeschlossene Phase 19.27 (2026-03-18):**
- DemoSupport-Typealiases entfernt; DemoDataLoader nutzt AppSessionContent direkt
- Public-API-Docs (///) auf AppSessionState, AppContentLoader, DemoDataLoader
- Dead Code entfernt: leeres .task {} + restoreBookmarkedFile() aus AppShellRootView
- AppDateDisplay.isoFormatter: Kommentar zu en_US_POSIX-Pflicht

**Abgeschlossene Phase 19.26 (2026-03-18):**
- AppContentSplitView.swift (1677 Zeilen) in 6 Dateien aufgeteilt:
  AppDisplayHelpers, AppSessionStatusView, AppOverviewSection,
  AppDayListView, AppDayDetailView, AppInsightsContentView
- Hauptview AppContentSplitView.swift auf 444 Zeilen reduziert
- Alle shared Helfer als internal deklariert (module-weit nutzbar)

**Abgeschlossene Phase 19.25 (2026-03-18):**
- "Paths" -> "Routes" im gesamten Display-Layer
- Daily Averages nur bei daySummaries.count >= 2
- Distance Chart: "Route distances only" Caption
- Activity Breakdown: colorForActivityType() pro Typ (Walking=gruen, etc.)

**Abgeschlossene Phase 19.24 (2026-03-18):**
- DayTimelineView: VoiceOver-Label (accessibilitySummary)
- coloredCard: .accessibilityElement(children: .combine)
- iOS-16 Map-Fallback; dayTimeRange .secondary; statusText .secondary
- Empty States: "No Content"->"Nothing Recorded", "No Day Selected"->"Select a Day",
  "No Day Details"->"No Day Entries"

**Abgeschlossene Phase 19.23 (2026-03-18):**
- CI: GitHub Actions swift-test.yml (Core) + xcode-test.yml (Wrapper)
- SwiftLint: .swiftlint.yml in beiden Repos, Clean-Exit-0-Baseline
- ZIPFoundation: .upToNextMinor(from: "0.9.19"), Package.resolved committed
- onChange deprecated -> .task(id:) (iOS 15+, nicht deprecated)
- Wrapper-Tests: 8 echte Unit-Tests (8/8 gruen, iPhone 17 iOS 26.3.1)
