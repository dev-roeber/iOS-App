# Deep Audit — Doku-Truth-Sync gegen Repo-Stand

**Datum/Uhrzeit**: 2026-05-06 (Lokal-Acceptance-Run)
**Repo-Pfad**: `/Users/sebastian/iOS-App` (macOS-Lokal; Mono-Repo aus Core-Package + `wrapper/`-Subdir)
**Hinweis zum Auftrag**: Die im Auftragstext genannten Linux-Pfade `/home/sebastian/repos/LocationHistory2GPX-iOS` und `/home/sebastian/repos/LH2GPXWrapper` existieren auf diesem System nicht. Der aktive Repo-Stand ist `dev-roeber/iOS-App` auf macOS (siehe README L82-88: `LocationHistory2GPX-iOS` und `LH2GPXWrapper` sind explizit als historische Repos markiert).
**Branch**: `main`
**Start-HEAD**: `f2e1d21`
**End-HEAD**: `93109e0` (docs: deep audit and truth-sync project documentation, 2026-05-06 09:57). **Folge-Audit (post-Audit-Doku-Sync, 2026-05-06 Abend)**: HEAD post-`70254ff` hat den Doku-Stand nach MapLayerMenu, Heatmap-Tier-2, Tempolayer, SIGABRT-Fix, Build-Bump 96→100 und MapLayerMenu-Wiring-Polish erneut nachgezogen — siehe `CHANGELOG.md` und `ROADMAP.md`.
**Auditor**: Claude Code (Opus 4.7)

---

## 1. Ausgeführte Befehle (verbatim)

```bash
pwd                                  # /Users/sebastian/iOS-App
git status --short                   # nur untracked .claude/ (gitignored)
git branch --show-current            # main
git remote -v                        # origin → github.com/dev-roeber/iOS-App.git
git fetch --all --prune              # ok
git log --oneline -12                # f2e1d21..ef42b98
swift build                          # Build complete
swift test                           # 949 tests, 2 skipped, 0 failures (7.7s)
xcodebuild -scheme LH2GPXWrapper \
  -project wrapper/LH2GPXWrapper.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath $TMPDIR/dd-doc-audit build
                                     # BUILD SUCCEEDED
```

## 2. Repo-Truth (verifiziert in dieser Session)

| Aspekt | Wert | Beleg |
|---|---|---|
| HEAD | `f2e1d21` | `git log --oneline -1` |
| Letzte 5 Commits | `f2e1d21` chore-untrack, `367d8e6` Export-Button-Fix, `0d043a3` Live-overlay-Gate, `b00d483` Polish, `51d45e2` Export-Empty-State | `git log` |
| `swift test` | 949 Tests, 2 Skips, 0 Failures | live in dieser Session |
| `xcodebuild` Wrapper iPhone 17 Pro Max Sim | BUILD SUCCEEDED | live, mit Sandbox-Override |
| ASC Build 74 (Version 1.0) | Accepted, Pending Developer Release | NEXT_STEPS L9, CHANGELOG 2026-05-05 Z.398 |
| 1.0-Train | abgeschlossen (Builds 80-83 verworfen wegen ITMS-90186/90062) | NEXT_STEPS L10 |
| MARKETING_VERSION | 1.0.1 (gesetzt 2026-05-05) | NEXT_STEPS L11 |
| Xcode Cloud Build 84 (1.0.1) | grün | NEXT_STEPS L12 |
| Build 95 / 96 | 95 veraltet (vor Hero-Map); 96 nötig | NEXT_STEPS L13-17 |
| Hero-Map-Workspace | gelandet 2026-05-06 (commit `e11d4d7`) | git log |
| LiveStatusResolver | gelandet 2026-05-06 (commit `709155f`); 16 dedizierte Tests | LiveStatusResolverTests.swift |
| Export Empty-State Cleanup | gelandet 2026-05-06 (`51d45e2`) | git log |
| Doppelter `.fileExporter` (Export-Button-Bug) | behoben 2026-05-06 (`367d8e6`) | AppExportView.swift L1230-1259 |
| Hardware iPhone 15 Pro Max | letzte Verifikation 2026-05-05 (Build 74-Stand vor Hero-Map); NACH Hero-Map nicht erneut auf Hardware | NEXT_STEPS L26 |

## 3. Geprüfte Dateien

**Root**: README.md, CHANGELOG.md, NEXT_STEPS.md, ROADMAP.md, AGENTS.md, Package.swift, Package.resolved
**docs/**: APP_FEATURE_INVENTORY.md, APPLE_VERIFICATION_CHECKLIST.md, CONTRACT.md, XCODE_APP_PREPARATION.md, XCODE_RUNBOOK.md, ASC_SUBMIT_RUNBOOK.md, XCODE_CLOUD_RUNBOOK.md, PRIVACY_MANIFEST_SCOPE.md, APP_REVIEW_RESPONSE_GUIDELINE_3_2.md, NOTION_SYNC_DRAFT.md, WIDGET_XCODE_SETUP.md
**wrapper/**: README.md, CHANGELOG.md, ROADMAP.md, NEXT_STEPS.md, docs/LOCAL_IPHONE_RUNBOOK.md, docs/TESTFLIGHT_RUNBOOK.md
**LH2GPXWrapper.xcodeproj/project.pbxproj**: stichprobenartig (MARKETING_VERSION, CURRENT_PROJECT_VERSION)

## 4. Audit-Matrix — Doku-Repo-Widersprüche (vor Korrektur)

| Bereich | Behauptung in Doku | Repo-Befund | Beleg | Bewertung | Korrektur |
|---|---|---|---|---|---|
| Review-Status | README L109: "Einreichung und weiterer Review-Verlauf bleiben offen" | Build 74 accepted, Pending Developer Release | NEXT_STEPS L9 | falsch | korrigiert in dieser Session |
| Lokales Archive | README L110: "1.0 (45)" Archive | MARKETING_VERSION jetzt 1.0.1; TestFlight via Xcode Cloud | wrapper/CHANGELOG, project.pbxproj | veraltet | korrigiert |
| Wrapper README ASC-Truth | wrapper/README L154-157: "1.0 in Warten auf Prüfung; Build 52 in Review; Builds 55-57" | Build 74 accepted, 1.0.1-Train aktiv | NEXT_STEPS, CHANGELOG | falsch | korrigiert |
| Wrapper README Linux-Server | wrapper/README L123: "xcodebuild auf Linux-Server nicht verfügbar" | macOS lokal, xcodebuild grün | live in Session | veraltet | korrigiert |
| docs/XCODE_RUNBOOK ASC-Block | L212-217: "1.0 / 52 / 55-57" | Build 74 accepted, 1.0.1/84/96 | NEXT_STEPS | falsch | korrigiert (historischer + aktueller Block) |
| docs/XCODE_CLOUD_RUNBOOK ASC-Block | L89-94: "1.0 / 52 / 55-57" | Build 74 accepted, 1.0.1/84/96 | NEXT_STEPS | falsch | korrigiert |
| docs/XCODE_APP_PREPARATION L47 | "Build 52 sichtbar; Builds 55-57 in Cloud" | Build 74 accepted, 1.0.1-Train | NEXT_STEPS | falsch | korrigiert |
| docs/XCODE_APP_PREPARATION L73 | "swift test 647 Tests am 2026-04-29" | 949 Tests, 2 Skips am 2026-05-06 | live in Session | veraltet | korrigiert |
| docs/APPLE_VERIFICATION_CHECKLIST | "927 Tests" mehrfach | 949 Tests am 2026-05-06 | live in Session | veraltet | korrigiert (Hinweis auf 949 ergänzt; historische 927-Datierung erhalten) |
| ROADMAP.md Stand | L3: "(2026-05-06)" | passt | live | wahr | – |
| CHANGELOG.md Top | 949 Tests, Build 96 nötig | passt | live | wahr | – |
| NEXT_STEPS.md Stand | "(2026-05-06 ...)" | passt | live | wahr | – |
| AGENTS.md | Repo-Architektur konsistent | passt | live | wahr | – |
| docs/CONTRACT.md | keine Test-Zahlen / ASC-Aussagen | passt | live | wahr | – |
| docs/APP_FEATURE_INVENTORY.md | Top auf 2026-05-06, 1.0.1/84/96 | passt | live | wahr | – |
| ASC_SUBMIT_RUNBOOK L19 | HEAD `3057cfc` | HEAD jetzt f2e1d21 | git | veraltet | **defer** (Audit-Snapshot dieses Datums) |
| ASC_SUBMIT_RUNBOOK Screenshot-Zahl | 8 Screenshots erwähnt | nur 6 Slots in `iphone-67/` | docs/app-store-assets/ | inkonsistent zwischen Docs | **defer** (separate Doc-Konsolidierungsphase) |
| wrapper/CHANGELOG historische Test-Zahlen | "933/0", "927/0", "228/0" | je Commit korrekt | git history | wahr | **defer** (historisch) |

## 5. Korrigierte Aussagen (in dieser Session)

| Datei | Edit | Risiko |
|---|---|---|
| README.md L109-110 | Review-Stand "offen" → "accepted, Pending Developer Release"; Archive-Hinweis auf 1.0.1-Train; Hardware-Verifikations-Caveat ergänzt | medium |
| wrapper/README.md L123 | "Linux-Server" → "macOS lokal, BUILD SUCCEEDED 2026-05-06"; Hardware-Verifikation 2026-05-05 dokumentiert | low |
| wrapper/README.md L154-157 | ASC-Truth komplett auf Stand 2026-05-06 (Build 74 accepted, 1.0.1/84/96, ITMS-90186 erläutert) | medium |
| docs/APPLE_VERIFICATION_CHECKLIST.md L43, L97 | "927" → Hinweis auf aktuelle 949 ergänzt, historische 927-Datierung erhalten | low |
| docs/XCODE_RUNBOOK.md L212-217 | historischen ASC-Block markiert + neuen 2026-05-06-Block ergänzt (Build 74 accepted, 1.0.1/84/96, 949 Tests, xcodebuild Sim grün) | medium |
| docs/XCODE_CLOUD_RUNBOOK.md L89-94 | analog: aktueller ASC-/Cloud-Truth + historischer 2026-04-30-Block | medium |
| docs/XCODE_CLOUD_RUNBOOK.md L87 | `CURRENT_PROJECT_VERSION = 45` → ergänzt um Cloud-`CI_BUILD_NUMBER`-Hinweis (84/96) | low |
| docs/XCODE_APP_PREPARATION.md L47 | "1.0 / 52 / 55-57" → "1.0.1-Train, Build 74 accepted, Build 84 grün, Build 96 nötig" | medium |
| docs/XCODE_APP_PREPARATION.md L73 | "647 Tests am 2026-04-29" → "949 Tests, 2 Skips, 0 Failures am 2026-05-06; historisch 647 am 2026-04-29" | low |

## 6. Bewusst NICHT geändert (Defer-Liste)

| Bereich | Begründung |
|---|---|
| CHANGELOG.md historische Einträge mit "933/0", "927/0" Test-Zahlen | je Commit historisch korrekt |
| wrapper/CHANGELOG.md L166, L189-198 (Linux-/228/217-Erwähnungen) | dokumentieren historische 2026-03/04-Phase |
| ROADMAP.md "Phase 19.xx"-Blöcke | historische Zeitleiste |
| NEXT_STEPS.md `[x]`-Items mit Daten 2026-04-30/2026-05-05 | historisch konsistent |
| APPLE_VERIFICATION_CHECKLIST L234ff (643/0, 616/0, 606/0, 586/0) | historische Snapshots, je Datum korrekt |
| docs/NOTION_SYNC_DRAFT.md | selbstdeklariert "Historischer Snapshot vom 2026-04-12 — nicht mehr kanonisch" |
| docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md | inhaltlich konsistent |
| ASC_SUBMIT_RUNBOOK.md L19 HEAD `3057cfc` | dokumentiert den Audit-Snapshot dieses Datums; eigene Doc-Phase |
| wrapper/docs/TESTFLIGHT_RUNBOOK.md L213, L216, L221 (Build 45) | Anleitungstext mit veraltetem Build-Beispiel; Korrektur in eigener Doc-Phase |

## 7. Build- und Testergebnisse

```
swift build:    Build complete (1.x s)
swift test:     Executed 949 tests, with 2 tests skipped and 0 failures (0 unexpected) in 7.6s
xcodebuild Wrapper iPhone 17 Pro Max Sim: ** BUILD SUCCEEDED **
git diff --check: clean (vor diesem Audit; nach diesem Audit ebenfalls erwartet sauber)
```

## 8. Weiterhin offene Risiken

### P0 (release-relevant)
- **Build 96 nicht getriggert**: Xcode Cloud `Release – Archive & TestFlight` Workflow muss manuell auf HEAD f2e1d21 gestartet werden, sonst kein Submit-Kandidat mit Hero-Map / LiveStatusResolver / Export-Fix. Bis zum Trigger gilt: kein Submit von 1.0.1.
- **Days-Screenshot iphone15pm_03**: muss vor Submit auf iPhone 15 Pro Max neu erzeugt werden (Sticky-Map-Layout-Drift seit 2026-05-05).
- **Hardware-Verifikation post-Hero-Map**: alle 2026-05-06-Änderungen (Hero-Map-Workspace, LiveStatusResolver, Export-Empty-State, fileExporter-Bug-Fix) sind nur auf Simulator + statisch verifiziert. Hardware-Smoke iPhone 15 Pro Max nötig vor Build-96-Submit.

### P1 (UX-Klärung)
- **Insights Triple-Range-Picker**: Hero-Strip + Time-Range-Card + untere Pills steuern denselben Zeitraum.
- **Overview Doppel-Header**: Page-Header "Overview" + Card-Titel "Overview" (mit KPI).
- **Map-Pill-Overlap**: "200 routes"/"11 routes"-Pill überlappt mit Snapshot-Banner.
- **Import-Phasen-Progress**: aktuell nur generischer Spinner.
- **Form-vs-LHCard-Konsistenz Settings**: General/Maps/Import nutzen `Form`, andere Sub-Views nutzen Custom-`LHCard`.

### P2 (Doku-Konsolidierung)
- **ASC_SUBMIT_RUNBOOK Screenshot-Anzahl**: 8 vs. 6 Slots inkonsistent zwischen `ASC_SUBMIT_RUNBOOK.md` und `APPLE_VERIFICATION_CHECKLIST.md`.
- **wrapper/docs/TESTFLIGHT_RUNBOOK.md**: Anleitungstexte mit Build-45-/v1.0-Beispielen sollten auf 1.0.1-Build-96-Beispiele umgeschrieben werden.
- **wrapper/ROADMAP.md**: Stand-Header 2026-03-31 → 2026-05-06 plus aktuelle 2026-05-06-Einträge.
- **wrapper/NEXT_STEPS.md**: 228-Tests-Zahl + Linux-Server-Erwähnung sollten auf 949 + macOS-Lokal aktualisiert werden.
- **ROADMAP.md**: Stand-Header ist 2026-05-06, aber kein inhaltlicher 2026-05-06-Block existiert (Hero-Map / LiveStatusResolver / Export-Empty-State / fileExporter-Fix). Strukturelle Lücke.
- **docs/PRIVACY_MANIFEST_SCOPE.md**: Stand-Header 2026-04-30 — nicht falsch (Privacy-Manifest hat sich nicht geändert), aber Datum kann auf 2026-05-06 angehoben werden.

### Security / Privacy
- **Live-Upload-Endpunkt-Default**: laut Code aktuell leer (`""`); Privacy-konform. Doku konsistent.
- **`AppLanguageSupport.swift`**: enthält keine Secrets.
- **`PrivacyInfo.xcprivacy`**: deklariert UserDefaults (CA92.1) + `NSPrivacyCollectedDataTypePreciseLocation`. Truth-konsistent.
- **Keine Secrets / Tokens / private URLs** in der Doku gefunden.

## 9. Was bewusst NICHT behauptet wurde

- App-Store-**Release** (App ist NICHT live; Pending Developer Release ≠ Released)
- Vollständige Hardware-Acceptance auf Hero-Map / LiveStatusResolver / Export-Fix-Stand (nur Sim + statisch)
- iPad-Layout-Acceptance (regularSplitView nicht visuell verifiziert)
- Landscape-Layout-Acceptance auf realer Hardware nach Hero-Map
- TestFlight-Beta-Tester-Rollout für 1.0.1
- App-Store-Connect Schritte (Build-Auswahl, Screenshots, Submit-Klick) — alles manuell offen
- Performance-Smoke mit großer realer History (>20 MB)
- Notion-Sync (kein MCP in dieser Session)

## 10. Nächste sinnvolle Schritte (priorisiert)

### P0 — Vor Submit
1. Xcode Cloud `Release – Archive & TestFlight` für HEAD f2e1d21 triggern → Build 96
2. iPhone 15 Pro Max Hardware-Smoke der 2026-05-06-Änderungen (`testAppStoreScreenshots`, `testDeviceSmokeNavigationAndActions`)
3. Days-Screenshot `iphone15pm_03` neu erfassen, in `docs/app-store-assets/screenshots/iphone-67/` ablegen
4. ASC: Version 1.0.1 mit Build 96 verknüpfen, Screenshots hochladen, Submit

### P1 — UX
1. Insights Triple-Range-Picker konsolidieren (1 Picker statt 3)
2. Overview Doppel-Header auflösen (Card umbenennen)
3. Map-Pill-Overlap (Z-Stack neu ordnen)

### P2 — Doku
1. ASC_SUBMIT_RUNBOOK Screenshot-Anzahl 8→6 konsistent machen
2. wrapper/docs/TESTFLIGHT_RUNBOOK Anleitungstexte auf 1.0.1/Build-96 anheben
3. ROADMAP.md 2026-05-06-Block ergänzen (Hero-Map / LiveStatusResolver / Export-Empty-State)
4. wrapper/ROADMAP.md + wrapper/NEXT_STEPS.md auf macOS-Lokal + 949 Tests umstellen

---

**Audit abgeschlossen**: 2026-05-06.
**End-HEAD**: `93109e0` (docs: deep audit and truth-sync project documentation, 2026-05-06 09:57).
