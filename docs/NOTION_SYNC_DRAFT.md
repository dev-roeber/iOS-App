# LH2GPX iOS-App — Notion Sync Draft
*Stand: 2026-04-12 | Quelle: Repo-Truth (Notion MCP war nicht verfügbar)*
*Direkt nach Notion übertragbar als To-do-Seite*

---

## A) Abgeschlossen ✅

### Global / Architektur / Repo-Struktur
| Titel | Status | Evidenz |
|---|---|---|
| Zentrales Repo iOS-App etabliert | ✅ | dev-roeber/iOS-App, Clone von Monorepo mit vollständiger History |
| Audit-Commits bestätigt | ✅ | be436f4, 9e6f00a, 3d7f6df, 7b13b48 in main |
| Monorepo als integrierter iOS-App-Stand | ✅ | Sources/ + wrapper/ im selben Repo |

### Übersicht / Import-Startseite
| Titel | Status | Evidenz |
|---|---|---|
| Google Maps Export Hilfe-Button (sichtbar, mit Text) | ✅ | GoogleMapsExportHelpInlineAction in ContentView.swift + AppShellRootView.swift |
| Google Maps Help Sheet (4 iPhone-Schritte, DE/EN) | ✅ | GoogleMapsExportHelpView.swift |
| Recent Files auf Startseite | ✅ | RecentFilesView.swift, RecentFilesStore.swift |
| Auto-Restore letzter Import | ✅ | AppImportStateBridge.swift |

### Tage
| Titel | Status | Evidenz |
|---|---|---|
| Tagesansicht mit Karte + Pfaden | ✅ | AppDayDetailView.swift, AppDayMapView.swift |
| Map Matching Beta-Toggle | ✅ | PathSimplification.swift (Douglas-Peucker, epsilon=15m) |
| AppDayPathDisplayMode (@AppStorage) | ✅ | AppPreferences.swift |
| Ehrliche Grenze: kein echtes Snapping | ✅ | Doku in CHANGELOG |

### Import / Export
| Titel | Status | Evidenz |
|---|---|---|
| GPX-Import (GPX 1.1) | ✅ | GPXImportParser.swift |
| TCX-Import (TCX 2.0) | ✅ | TCXImportParser.swift |
| Google Timeline JSON Import | ✅ | GoogleTimelineConverter.swift |
| LH2GPX JSON Import | ✅ | AppContentLoader.swift |
| ZIP-Import-Routing | ✅ | AppContentLoader.swift |
| GPX-Export | ✅ | ExportFormat.swift |
| Multi-Source-Import Tests | ✅ | MultiSourceImportTests.swift (19 Tests) |

### Live-Aufzeichnung
| Titel | Status | Evidenz |
|---|---|---|
| LiveLocationFeatureModel (Start/Stop/Permissions) | ✅ | LiveLocationFeatureModel.swift |
| LiveTrackRecorder (Accuracy/Dedupe/Distanz) | ✅ | LiveTrackRecorder.swift |
| Live Activity / ActivityKit (iOS 16.2+) | ✅ | ActivityManager.swift, TrackingAttributes.swift |
| NSSupportsLiveActivities in Info.plist | ✅ | wrapper/Config/Info.plist |
| Integration in FeatureModel + Recorder | ✅ | LiveLocationFeatureModel.swift, LiveTrackRecorder.swift |

### Tests / Qualität
| Titel | Status | Evidenz |
|---|---|---|
| 550 Tests, 0 Fehler (macOS) | ✅ | swift test 2026-04-12 |
| MapMatchingTests (9) | ✅ | Tests/LocationHistoryConsumerTests/MapMatchingTests.swift |
| LiveActivityTests (7) | ✅ | Tests/LocationHistoryConsumerTests/LiveActivityTests.swift |
| GoogleMapsExportHelpTests (4) | ✅ | Tests/LocationHistoryConsumerTests/GoogleMapsExportHelpTests.swift |
| MultiSourceImportTests (19) | ✅ | Tests/LocationHistoryConsumerTests/MultiSourceImportTests.swift |
| OverviewFavoritesAndInsightsTests (14) | ✅ | Tests/LocationHistoryConsumerTests/OverviewFavoritesAndInsightsTests.swift |

---

## B) Offen / Blockiert / Geparkt

### Widget / Live Activity / Dynamic Island UI
| Titel | Status | Nächster Schritt |
|---|---|---|
| Widget Extension Target in Xcode anlegen | 🔲 Offen | File > New Target > Widget Extension in Xcode GUI |
| Lock Screen Live Activity View | 🔲 Offen | SwiftUI View im Widget Extension Target |
| Dynamic Island expanded/compact/minimal | 🔲 Offen | ActivityConfiguration in Widget Extension |
| Pause/Resume-State im LiveRecording | 🔲 Offen | LiveLocationFeatureModel erweitern |
| Dynamic Island UI Verifikation (iPhone 14 Pro+) | ⛔ Blockiert | Braucht echtes Gerät |

### Map Matching
| Titel | Status | Nächster Schritt |
|---|---|---|
| Echtes Straßen-/Weg-Snapping | 🚫 Bewusst nicht | Kein nativer Apple-Support, keine externen Deps gewünscht |

### Xcode / Build / Release
| Titel | Status | Nächster Schritt |
|---|---|---|
| Apple-UI-Verifikation: Range-Picker, Datumsbereich | 🔲 Offen | Auf echtem iPhone testen |
| App Store / TestFlight / Release | ⏸ Geparkt | Blockiert bis Developer-Account-Zugang |

### Export
| Titel | Status | Nächster Schritt |
|---|---|---|
| KMZ-Export | 🔲 Offen | ExportFormat.swift erweitern |
| Chart-Share per ImageRenderer | 🔲 Offen | InsightsCardView.swift |

### Repo-Migration
| Titel | Status | Nächster Schritt |
|---|---|---|
| Split-Repos als historisch/mirror markieren | 🔲 Offen | README in LocationHistory2GPX-iOS, LH2GPXWrapper aktualisieren |

### Lokalisierung
| Titel | Status | Nächster Schritt |
|---|---|---|
| Vollständige DE-Lokalisierung aller EN-Strings | 🔶 Teilweise | AppLanguageSupport.swift ergänzen |

---

*Erstellt von Claude Sonnet 4.6 basierend auf Repo-Truth — 2026-04-12*
*Für Notion: Als Datenbank-Tabelle oder Checkbox-Liste einfügen*
