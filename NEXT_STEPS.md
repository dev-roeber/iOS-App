# NEXT_STEPS

Bereinigt gemaess AGENTS.md-Governance ("NEXT_STEPS darf nur offene, priorisierte naechste Arbeit enthalten") -- nur offene Punkte, extrahiert aus dem Stand vom 2026-05-28. Vollstaendiger historischer Verlauf inkl. erledigter Punkte: [docs/archive/NEXT_STEPS_FULL_2026-05-28.md](docs/archive/NEXT_STEPS_FULL_2026-05-28.md)


### Verbleibend offen — Xcode Cloud Archive-Fail Build 155/156 Retest (2026-05-08)

- [ ] **Xcode Cloud Retest „Release – Archive & TestFlight" auslösen** auf dem post-Fix-HEAD nach Commit. Status: **PENDING** — keine Aussage über echte Apple-Builds, bis Xcode Cloud erneut grün läuft.

### Verbleibend offen — Manual Release Risk Acceptance Protocol (HEAD `b91a933`)

- [ ] **46-MB-Crashfall (Großimport echtes iPhone)** — Status **FAILED** (drei reproduzierte Hardware-Fails am 2026-05-07: 13:38:37+02:00 / Op-Dauer 232.341 ms, 14:14:36+02:00 / 216.606 ms, 15:10:44+02:00 / **95.156 ms** auf iPhone 15 Pro Max, iOS 26.4 / 23E246, Xcode 26.3, macOS 15.7); Code-Stand vorbereitet bis HEAD `<commit-tba>` nach `ae5de1f` (autoreleasepool, Session/Builder/Calculator-Fix, **flatCoordinates-Kanonisierung** ~80–120 MB-Ersparnis, ImportMemoryProbe verdichtet, Build-Identitäts-Logging immer auf App-Start, Memory-Logging-Status in Settings → Technical → Build Info sichtbar) — kein verifizierter Erfolg. **Hardware-Retest mit der originalen 46-MB-ZIP steht weiter aus** (Mac/iPhone-Handoff — auf Linux-Server nicht durchführbar), bleibt FAILED bis Tester ihn grün bestätigt. Siehe Sektion 1 in `docs/APPLE_VERIFICATION_CHECKLIST.md` (Manual Release Risk Acceptance Protocol)
- [ ] **Hardware-Retest mit Build-Identitäts-Verifikation** — Tester muss vor dem Retest am Gerät Settings → Technical → „Build Info" öffnen und Marketing-Version + Build + (falls injiziert) Git-Commit-SHA + **„Memory Logging: Enabled"** mit dem getesteten Git-HEAD vergleichen, **bevor** der Import gestartet wird. Memory-Logging-Aktivierung: env `LH2GPX_IMPORT_MEMORY_LOG=1` **oder** Launch-Argument (`LH2GPX_IMPORT_MEMORY_LOG`, `-LH2GPX_IMPORT_MEMORY_LOG`, `--LH2GPX_IMPORT_MEMORY_LOG`, `LH2GPX_IMPORT_MEMORY_LOG=1`). Erst Debug-Run loggen (`[LH2GPX_BUILD]` + `[LH2GPX_MEMORY]` in Xcode-Console greppen), dann Release-Build ohne Debugger. **Restrisiko**: Code-Stand adressiert die wahrscheinlichsten Allokationspfade, ist aber kein Beweis für Release-Build-Verhalten unter realer iOS-Memory-Pressure — der dritte Fail (95 s Op-Dauer) zeigt: Peak liegt früher als bisher angenommen.
- [ ] **Live Activity / Dynamic Island / Lock Screen** — siehe Sektion 2 in `docs/APPLE_VERIFICATION_CHECKLIST.md` (Manual Release Risk Acceptance Protocol)
- [ ] **iPad-Layout (Days-Tab + Hero-Map-Workspace)** — siehe Sektion 3 in `docs/APPLE_VERIFICATION_CHECKLIST.md` (Manual Release Risk Acceptance Protocol)
- [ ] **ASC / TestFlight / Apple Review (1.0 Build 74 vs 1.0.1 Train, Build-Liste, nächster Submit-Schritt, ggf. Xcode Cloud Build ≥ 100)** — siehe Sektion 4 in `docs/APPLE_VERIFICATION_CHECKLIST.md` (Manual Release Risk Acceptance Protocol)

### Audit-Batch 2026-05-07 (Bündel B+C+D+A) — 22 Achsen erledigt

- [ ] **P2-8** (bewusst nicht angefasst): Live `mapCard` (Landscape) und `liveHeroMap` (Portrait) Duplikat-Refactor. `mapControlRow` hat realen Caller in `landscapeMapColumn` — Audit-Beschreibung war ungenau.
- [~] **P2-17 (SKIP)**: `wrapper/CI.xctestplan` unverändert. Test-Plan referenziert `LH2GPXWrapper.xcodeproj`-containerPath; SwiftPM-Test-Target `LocationHistoryConsumerPackageTests` ohne pbxproj-Integration nicht aufnehmbar. `.github/workflows/swift-test.yml` deckt SwiftPM-Suite weiterhin separat ab.
- [ ] **P2-16** (bewusst nicht angefasst): API-Naming-Vereinheitlichung `parse`/`convert`/`decode`/`load` — public-API-Rename mit Folgerisiken.
- [ ] **P2-18** (bewusst nicht angefasst): `HeatmapGridBuilder` MapKit-Entkopplung — public-API-Rename mit Folgerisiken.

### Audit-Batch 2026-05-07 (Phase 1-5, items 2-15) — 14 Achsen erledigt

- [~] **Item 10** — `wrapper/CI.xctestplan` SwiftPM-Coverage **SKIP** — pbxproj-Integration zu fragil, out-of-scope.

## P0 — Release / Review / Hardware-Verifikation

- [ ] **Xcode Cloud Build ≥100 triggern** (Pflicht vor Submit):
  - Build 95 ist veraltet; `CURRENT_PROJECT_VERSION` lokal auf `100` angehoben (commit `8854eef`, 2026-05-06).
  - Neuester Commit-Stand: `feat: unify map layer controls into single right-side dropdown` (`70254ff`) plus Doku-/Wiring-Audit-Polish.
  - Xcode Cloud Workflow `Release – Archive & TestFlight` manuell anstoßen.
  - Visuelle Verifikation am echten iPhone 15 Pro Max steht noch aus (App ist installiert + gestartet).
- [ ] **Days-Screenshot (iphone15pm_03) neu aufnehmen**: UITest `testAppStoreScreenshots` auf iPhone 15 Pro Max ausführen — Days-Layout erneut verändert (Control-Clearance, kein schwarzer Gap, kompakter Filter). Neues PNG in `docs/app-store-assets/screenshots/iphone-67/` ablegen.
- [ ] **Version 1.0.1 in App Store Connect finalisieren** (nach neuem Cloud-Build):
  1. ASC → LH2GPX → Vertrieb → iOS-App Version `1.0.1` öffnen
  2. Neuen Build (**≥ 100**, nach diesem Commit) auswählen, speichern — **nicht Build 95 oder früher**
  3. Screenshots prüfen: 6 iPhone-15-Pro-Max-PNGs aus `docs/app-store-assets/screenshots/iphone-67/` hochladen (iphone15pm_01–06, 1290×2796 px)
  4. `Zur Prüfung einreichen` (`Submit for Review`)
  - Runbook: `docs/ASC_SUBMIT_RUNBOOK.md`
- [ ] Live Activity / Dynamic Island auf echter Hardware vervollstaendigen: Lock Screen, `minimal`, Fallback bei deaktivierten / nicht verfuegbaren Live Activities, No-Dynamic-Island-Geraet (Pending-/Restart-Pfad jetzt gruen)
- [ ] Days-Tab: iPad-Verifikation — `regularSplitView` nutzt `daysMapHeaderCard` via `AnyView`, visuell ungeprüft
- [ ] **Hero-Map-Workspace iPad/Landscape-Verifikation**: Compact iPhone vereinheitlicht (commit e11d4d7, 2026-05-06) — Übersicht/Insights/Export/Live nutzen Tage-Hero-Stil. iPad-Regular und Landscape behalten Legacy-Pfade; visuelle Verifikation an realem iPad + iPhone-Landscape steht aus.
- [ ] **Cleanup-Follow-up Hero-Map**: `AppDayDetailView.mapControlRow` ist im Portrait toter Code (Landscape-only). Live `mapCard` (Landscape) und `liveHeroMap` (Portrait) duplizieren Map-Rendering — Konsolidierung in shared ViewBuilder.
- [ ] **46-MB-Crashfall — Hardware-Re-Verifikation**: durch Sniffer-Skip im Auto-Restore-Pfad guarded (rohe Google-Timeline wird unabhängig von der Größe nicht mehr auto-restored, deckt 46 < 50 MB-Lücke). Hardware-Re-Verifikation auf iPhone 15 Pro Max mit echter 46-MB-`location-history.zip` steht aus (kein Simulator hat den Fall realistisch nachgestellt).
- [~] **Streaming-/Chunked-Google-Timeline-Parser**: implementiert für direkte JSON-Imports (2026-05-06) — `GoogleTimelineStreamReader` (FileHandle, jetzt 256-KB-Chunks, UnsafeBytes-Tokenizer mit `@inline(__always)`-Hot-Path und Hex-Literalen, 8-MB-Element-Cap) plus `GoogleTimelineConverter.convertStreaming(contentsOf:)`; `AppContentLoader.decodeFile` sniffed `[` und geht direkt in den URL-Pfad ohne `Data(contentsOf:)`. **Direct-Model-Build umgesetzt (2026-05-06):** `GoogleTimelineConverter` baut `AppExport`/`Day`/`Visit`/`Activity`/`Path` jetzt direkt über public memberwise-Initializer; der frühere `[String: Any]`-Tree + `JSONSerialization`-Encode + Re-Decode auf der Output-Seite entfällt. Per-Element-`onElement` läuft in `autoreleasepool`, damit Foundation-Zwischenobjekte nicht akkumulieren. **Offen:** Mikro-Benchmark (kein gemessener Speedup-Faktor — bislang nur erwartete Größenordnungen) und Hardware-Re-Verifikation auf iPhone 15 Pro Max mit echter 46-MB-Datei. ZIP-Entry-Streaming wurde am 2026-05-07 ergänzt (Sniffer-basiert; greift bei genau einem Google-Timeline-Entry, kein Mixed-ZIP — Peak RAM auf ~ein Element). Mikro-Benchmark als `XCTest`-`measure`-Baseline ergänzt (kein fail-on-regression bar; weiterhin kein gemessener Speedup-Faktor). Auto-Restore lehnt rohe Google-Timeline-Dateien weiterhin ab.
- [ ] Performance-Smoke-Test auf echtem iPhone mit grosser realer History (>20 MB, Gesamtzeitraum) fuer Overview-/Explore-Karte dokumentieren — neu motiviert durch Jetsam-Kill bei 46 MB Google-Timeline-Auto-Restore (Auto-Restore-Schutz greift; manueller Import des großen Files muss noch hardware-verifiziert werden)

## P1 — Produktverifikation und Ausbau vorhandener Flaechen

- [ ] Chart-Share / ImageRenderer auf Apple-Hardware gezielt verifizieren
- [ ] app-weite Landscape-Verifikation fuer `Overview`, `Days`, `Insights`, `Export`, `Live`
- [ ] Homescreen-Widget auf echter Hardware gezielt verifizieren
- [ ] Wrapper-Simulator-Testlauf fuer `LH2GPXWrapperTests` auf diesem Host stabilisieren oder auf anderem Apple-Host gegentesten (`NSMachErrorDomain Code=-308`)

## P2 — Nachgelagerte Optimierung

- [ ] Widget/Dynamic-Island nur bei sicherem Token-Pfad weiter ausbauen
- [ ] `LHCollapsibleMapHeader` in erste echte Seite einbauen (Kandidat: Insights-Heatmap-Kontext oder Overview-Map); nur wenn Daten sauber verfügbar
- [ ] Apple-Review-/Privacy-Einordnung fuer den optionalen Server-Upload weiter beobachten und nach Review-Feedback repo-wahr nachziehen
- [ ] `docs/NOTION_SYNC_DRAFT.md` nur noch als manuell gepflegten Snapshot nutzen oder spaeter durch einen schlankeren Status-Export ersetzen
- [ ] historische Split-Repos `LocationHistory2GPX-iOS` und `LH2GPXWrapper` konsistent als historisch/mirror markieren
- [ ] echtes Road-/Path-Matching nur als spaeteren separaten Produktentscheid evaluieren; aktueller Stand bleibt bewusst `Simplified` statt Snapping
