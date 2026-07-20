# AUDIT 4-Repo Master – 2026-03-31_08-16

## 1. Ziel / Scope

Kompromissloser 4-Repo-Truth-Sync, Doku-Glattzug und globaler Preflight/Deep-Audit ueber:

- `LocationHistory2GPX` (Core/Python-Producer)
- `LocationHistory2GPX-iOS` (iOS-Consumer/Swift-Package)
- `LH2GPXWrapper` (Xcode-Wrapper/iOS-App)
- `lh2gpx-live-receiver` (FastAPI-Receiver-Server)

## 2. Reihenfolge und Begruendung

1. LocationHistory2GPX (Core) – Basis fuer Contract und Truth
2. LocationHistory2GPX-iOS – primaerer Consumer
3. LH2GPXWrapper – abhaengig vom iOS-Repo
4. lh2gpx-live-receiver – eigenstaendiger Server-Strang
5. Cross-Repo-Audit-Pass

## 3. Gelesene Pflichtdateien je Repo

### LocationHistory2GPX
README.md, CHANGELOG.md, ROADMAP.md, NEXT_STEPS.md, AGENTS.md, pyproject.toml, lh2gpx/version.py, docs/SEPARATE_IOS_REPO_BOUNDARY.md, docs/APP_INTEGRATION.md (referenced), roadmap/roadmap.yaml, PROJECT_SUMMARY.md, INVENTORY.json, IR_SCHEMA.md, app_export.schema.json

### LocationHistory2GPX-iOS
README.md, CHANGELOG.md, NEXT_STEPS.md, AGENTS.md, ROADMAP.md, Package.swift, Package.resolved, docs/CONTRACT.md, docs/APP_FEATURE_INVENTORY.md, docs/APPLE_VERIFICATION_CHECKLIST.md, docs/XCODE_APP_PREPARATION.md, docs/XCODE_RUNBOOK.md, .github/workflows/swift-test.yml, audits/AUDIT_MASTER_2026-03-31_04-59.md, audits/AUDIT_HARDMODE_CROSS_REPO_2026-03-31_04-59.md

### LH2GPXWrapper
README.md, CHANGELOG.md, NEXT_STEPS.md, ROADMAP.md, docs/LOCAL_IPHONE_RUNBOOK.md, docs/TESTFLIGHT_RUNBOOK.md, AUDIT_MASTER_2026-03-31_04-59.md, AUDIT_HARDMODE_WRAPPER_2026-03-31_04-59.md, Config/Info.plist, LH2GPXWrapper/PrivacyInfo.xcprivacy, LH2GPXWrapper.xctestplan, .github/workflows/xcode-test.yml

### lh2gpx-live-receiver
README.md, CHANGELOG.md, .env.example, .env (lokal, nicht versioniert), compose.yaml, Caddyfile, Dockerfile, requirements.txt, requirements-dev.txt, .gitignore, app/main.py, app/config.py, app/models.py, app/storage.py, tests/test_app.py, tests/conftest.py, scripts/run-local.sh, scripts/smoke-test.sh, scripts/container-entrypoint.sh, docs/API.md, docs/ARCHITECTURE.md, docs/DATA_MODEL.md, docs/OPERATIONS.md, docs/SECURITY.md, docs/TROUBLESHOOTING.md, docs/APPSTORE_PRIVACY_NOTES.md, docs/DEPLOY_RUNBOOK.md, docs/OPEN_ITEMS.md

## 4. Pflichtdateien nicht vorhanden

### LocationHistory2GPX
- Kein `audits/`-Verzeichnis (Audit-Dateien liegen im Root; bestehende Konvention respektiert)

### LocationHistory2GPX-iOS
- Kein `AGENTS.md`-Backup noetig (nicht geaendert)

### LH2GPXWrapper
- Kein `docs/`-internes Audit-Verzeichnis (Audit-Dateien liegen im Root; bestehende Konvention respektiert)

### lh2gpx-live-receiver
- Keine ROADMAP.md, keine NEXT_STEPS.md (offene Punkte stehen in docs/OPEN_ITEMS.md; bestehende Konvention)

## 5. Zusaetzlich entdeckte relevante Dateien

### LocationHistory2GPX
ANALYSIS_REPORT.md, APP_SCHEMA_CHANGELOG.md, AUDIT_RUNLOG.txt, BRANCH_CONSOLIDATION.md, CODEX_DEEP_AUDIT_REPORT.md, DEEP_AUDIT_2026_03.md, DEEP_AUDIT_2026_03_14.md, DEEP_AUDIT_REPORT.md, DEV_SMOKE_TESTS.md, FULL_AUDIT_REPORT.md, ROADMAP_AUDIT.md, TROUBLESHOOTING.md, THIRD_PARTY_LICENSES.md, docs/CI_AND_TESTING.md, docs/CI_WORKFLOWS_LOCAL.md, docs/GITHUB_ISSUES.md, docs/LOCAL_TESTING.md, docs/REPO_AUDIT.md, docs/REQUIRED_STATUS_CHECK.md, scripts/*, testdata/*, ios_smoke/*

### LocationHistory2GPX-iOS
Fixtures/contract/*, Sources/* (ca. 70+ Swift-Dateien), Tests/* (ca. 40+ Testdateien), scripts/update_contract_fixtures.sh, scripts/run_app_shell_macos.sh, .swiftlint.yml

### LH2GPXWrapper
LH2GPXWrapper.xcodeproj/project.pbxproj, LH2GPXWrapper/ContentView.swift, LH2GPXWrapper/LH2GPXWrapperApp.swift, LH2GPXWrapperTests/*, LH2GPXWrapperUITests/*, LH2GPXWrapper/Assets.xcassets/*, docs/appstore-screenshots/*, .swiftlint.yml

### lh2gpx-live-receiver
app/templates/*, app/static/style.css, .backup/2026-03-31_06-19/*, data/ (lokal, gitignored)

## 6. Bewusst nicht vertiefte Dateien

- LocationHistory2GPX: AUDIT_RUNLOG.txt (141 KB, historisch, nicht editierbar), .github/workflows_archive/* (archiviert), testdata/golden/*.json (deterministisch generiert)
- LocationHistory2GPX-iOS: Alle ~70 Swift-Source-Dateien einzeln (Scope ist Doku-Wahrheit, nicht Code-Review)
- LH2GPXWrapper: project.pbxproj (Xcode-generiert)
- lh2gpx-live-receiver: app/templates/*.html (Jinja2-Templates, nicht wahrheitskritisch), .backup/* (automatisches Backup)

## 7. Ausgefuehrte Pruefungen / Tests / Befehle

### LocationHistory2GPX
- `python3 -m unittest discover tests`: 143 Tests, 1 skipped, 0 Failures
- `python3 scripts/build_roadmap.py`: regeneriert
- `python3 scripts/check_repo_truth.py`: konsistent
- `git diff --check`: sauber

### LocationHistory2GPX-iOS
- `swift test`: 228 Tests, 2 Skips, 0 Failures
- `git diff --check`: sauber
- `which xcodebuild`: nicht vorhanden – auf diesem Linux-Host nicht verifiziert

### LH2GPXWrapper
- `git diff --check`: sauber
- `which xcodebuild`: nicht vorhanden – auf diesem Linux-Host nicht verifiziert

### lh2gpx-live-receiver
- `python3 -m pytest tests/ -q --tb=short`: 14 Tests, 0 Failures
- `docker compose config`: valide
- `git diff --check`: sauber

### Tooling-Check
- Swift: vorhanden (/usr/local/bin/swift)
- xcodebuild: nicht vorhanden
- Docker Compose: v5.1.1

## 8. Cross-Repo-Widersprueche VOR Korrektur

1. **Core-Roadmap `separate-ios-repo` Stale-Claim**: Core-ROADMAP.md und roadmap.yaml sagten `PARTIAL` mit Note "Noch nicht erledigt: separates Swift-Repo bootstrapen". Realitaet: Das iOS-Repo existiert mit 228 Tests, CI, Produkt-UI und Wrapper-Repo. Klar stale.

2. **Hardcoded Test-Server-IP in iOS-Repo**: `LiveLocationServerUploader.swift` Zeile 7 hat `https://178-104-51-78.sslip.io/live-location` als Default. Bereits dokumentiert in receiver OPEN_ITEMS.md als deferred. Keine Aenderung in diesem Audit (Code-Aenderung, nicht Doku-Wahrheit).

3. **Keine weiteren inhaltlichen Cross-Repo-Drifts**: Der vorherige Audit-Lauf (04-59) hatte Core/iOS/Wrapper bereits synchronisiert. Die Doku zwischen iOS und Wrapper ist konsistent.

## 9. Cross-Repo-Korrekturen

1. Core `roadmap.yaml`: `separate-ios-repo` von `partial` auf `done` gesetzt; Summary, Notes und Next-Steps-Eintrag aktualisiert.
2. Core generierte Dateien (ROADMAP.md, NEXT_STEPS.md, PROJECT_SUMMARY.md, INVENTORY.json, roadmap_report.json) regeneriert.
3. Core README.md: "Separate iOS Repo Boundary"-Abschnitt aktualisiert – "Ein spaeteres separates iOS-Repo" durch Verweis auf das existierende Repo ersetzt.

## 10. Verbleibende Cross-Repo-Risiken

1. Hardcoded Test-Server-IP (`178-104-51-78.sslip.io`) in iOS-Repo Swift-Code und diversen Changelogs/Docs. Bereits als offener Punkt dokumentiert (receiver OPEN_ITEMS.md, iOS/Wrapper NEXT_STEPS Phase 19.56). Keine Code-Aenderung in diesem Audit.
2. Kein frischer Apple-CLI-Gegenlauf fuer den aktuellen iOS- und Wrapper-Stand. Auf diesem Linux-Host nicht moeglich.
3. Privacy-/Review-Einordnung fuer den optionalen Server-Upload ist nicht abgeschlossen (dokumentiert in NEXT_STEPS Phase 19.56).
4. Token-Rotation fuer den laufenden Receiver-Test-Token steht aus (dokumentiert in receiver OPEN_ITEMS.md).

## 11. Gesamtbild des Projekts

LocationHistory2GPX ist ein 4-Repo-Projekt:

| Repo | Rolle | Sprache | Tests | Verifikationsgrad |
|------|-------|---------|-------|-------------------|
| LocationHistory2GPX | Python-Producer: Parsing, Export, Contract | Python 3.10+ | 143 unittest (frisch) | Vollstaendig auf Linux |
| LocationHistory2GPX-iOS | iOS-Consumer: Decoder, Queries, UI | Swift 5.9 | 228 swift test (frisch auf Linux) | Linux-Tests gruen; Apple-Build/Device historisch 2026-03-30 |
| LH2GPXWrapper | Xcode-App-Huelle: Bundle, Signing, Assets | Swift/Xcode | Xcode-Tests historisch | Nur historische Apple-Nachweise; auf Linux nicht baubar |
| lh2gpx-live-receiver | FastAPI-Server: Live-Location-Ingest | Python 3.12 | 14 pytest (frisch) | Vollstaendig auf Linux; Docker-deployed |

Der Contract-Fluss ist: Core produziert `app_export.schema.json`-konforme JSON-Artefakte -> iOS-Repo konsumiert sie -> Wrapper liefert die iOS-App-Huelle -> Receiver nimmt optional Live-Punkte entgegen.

## 12. Globaler Masterstatus je Repo

### LocationHistory2GPX
- Rolle: Python-Producer
- Ist-Stand: v1.8.2, 143 Tests gruen, Roadmap vollstaendig done (11/11)
- Verifikationsgrad: Vollstaendig auf Linux
- Wichtigste Risiken: Keine offenen Roadmap-Items mehr. ios_smoke bleibt als Referenz.
- Wichtigste naechste Schritte: Contract-Pflege bei Bedarf.

### LocationHistory2GPX-iOS
- Rolle: iOS-Consumer mit Produkt-UI
- Ist-Stand: 228 Tests (Linux), historisch 224 Tests (macOS 2026-03-30), produktnahe App-Shell mit Live/Upload/Insights/Heatmap/Export
- Verifikationsgrad: Linux-Tests frisch; Apple-Build/Device nur historisch
- Wichtigste Risiken: Kein frischer Apple-CLI-Gegenlauf; Heatmap/Live/Upload/Background-Recording nicht auf Apple-Hardware verifiziert; Hardcoded Test-Server-IP
- Wichtigste naechste Schritte: Phase 19.51-19.56 (Apple-Verifikation, Device-Tests, Privacy/Review)

### LH2GPXWrapper
- Rolle: Xcode-App-Huelle
- Ist-Stand: iOS-Build historisch gruen (2026-03-30), Simulator-Tests historisch gruen
- Verifikationsgrad: Nur historische Apple-Nachweise; auf Linux nicht baubar
- Wichtigste Risiken: Kein frischer xcodebuild-Lauf; Privacy-Manifest-Scope fuer Upload ungeklaert
- Wichtigste naechste Schritte: Frischer Apple-CLI-Gegenlauf; Device-Verifikation

### lh2gpx-live-receiver
- Rolle: FastAPI-Server fuer Live-Location-Ingest
- Ist-Stand: 14 Tests gruen, Docker-deployed, Merge nach main verifiziert
- Verifikationsgrad: Vollstaendig auf Linux; Docker Compose valide
- Wichtigste Risiken: Test-Token nicht rotiert; Admin-Auth nur Basic/lokal; keine automatische Retention
- Wichtigste naechste Schritte: Token-Rotation; Admin-Auth-Haertung; Retention-Konzept

## 13. Ehrliche Grenzen der Verifikation

- Linux-Host ohne `xcodebuild`: Keine Apple-Build-, Simulator- oder Device-Verifikation moeglich.
- Historische Apple-Nachweise (2026-03-17 und 2026-03-30) wurden dokumentarisch uebernommen, nicht praktisch erneut bestaetigt.
- Die hardcoded Test-Server-IP im iOS-Code wurde als offener Punkt dokumentiert, aber nicht in diesem Audit geaendert (Code-Aenderung, nicht Doku-Truth).
- Die `.env`-Datei mit echtem Bearer-Token auf dem Receiver-Server ist lokal und nicht versioniert (korrekt gitignored).

## 14. Abschlussfazit

Der 4-Repo-Wahrheitsstand ist nach diesem Audit konsistent:

- Eine sachliche Stale-Korrektur im Core-Repo: `separate-ios-repo` von `partial` auf `done`.
- Die 3 anderen Repos (iOS, Wrapper, Receiver) brauchten nach dem 04-59-Audit keine inhaltlichen Aenderungen – nur dieses Master-Audit-Artefakt.
- Alle nicht frisch belegten Apple-/Device-/Review-Themen bleiben explizit offen.
- Die naechste produktive Arbeit liegt bei den Apple-Verifikationen (Phase 19.51-19.56) und der Token-/Privacy-Bereinigung.
