# AUDIT_HARDMODE_CORE_2026-03-31_04-59

## 1. Ziel / Scope

- Deep Audit des Core-Repos `LocationHistory2GPX-iOS`
- Abgleich von Doku, Code, Tests und Host-Realitaet
- repo-wahre Korrektur der betroffenen Core-Dokumentation
- keine neue Feature-Entwicklung

## 2. Gelesene Pflichtdateien

- `AGENTS.md`
- `CHANGELOG.md`
- `NEXT_STEPS.md`
- `README.md`
- `ROADMAP.md`
- `docs/APPLE_VERIFICATION_CHECKLIST.md`
- `docs/APP_FEATURE_INVENTORY.md`
- `docs/CONTRACT.md`
- `docs/XCODE_APP_PREPARATION.md`
- `docs/XCODE_RUNBOOK.md`

## 3. Zusätzlich entdeckte relevante Dateien

- `Package.swift`
- `Package.resolved`
- `.github/workflows/swift-test.yml`
- `scripts/update_contract_fixtures.sh`
- `scripts/run_app_shell_macos.sh`
- `Tests/LocationHistoryConsumerTests/AppContentLoaderTests.swift`
- `Tests/LocationHistoryConsumerTests/AppExportQueriesTests.swift`
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`
- `Tests/LocationHistoryConsumerTests/InsightsChartSupportTests.swift`
- `Tests/LocationHistoryConsumerTests/LiveLocationFeatureModelTests.swift`
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`
- `Sources/LocationHistoryConsumerAppSupport/AppInsightsContentView.swift`
- `Sources/LocationHistoryConsumerAppSupport/AppLiveTrackingView.swift`
- `Sources/LocationHistoryConsumerAppSupport/LiveLocationServerUploader.swift`
- `audits/AUDIT_HARDMODE_CORE_2026-03-30_10-35.md`
- `audits/AUDIT_HARDMODE_CROSS_REPO_2026-03-30_10-35.md`
- `audits/AUDIT_LH2GPX_2026-03-30_09-11.md`
- `audits/AUDIT_MASTER_2026-03-30_11-01.md`

## 4. Ausgeführte Prüfungen / Tests / Befehle

- `git fetch --all --prune`
  - Ergebnis: `origin/main` aktuell, neuer Audit-Branch angelegt
- `git checkout main && git pull --ff-only origin main && git checkout -b chore/preflight-deep-audit-2026-03-31_04-59`
  - Ergebnis: Branch sauber vom aktuellen `main` erzeugt
- `git status --short --branch`
  - Ergebnis: sauberer Arbeitsstand vor Änderungen
- `git log --oneline -n 5`
  - Ergebnis: aktuelle Spitze `8b132df`, `47ee106`, `555c87f`, `6b98fe8`, `8fca064`
- `command -v swift && swift --version`
  - Ergebnis: `/usr/local/bin/swift`, Swift 5.9 auf Linux
- `command -v xcodebuild`
  - Ergebnis: kein Treffer; Apple-CLI auf diesem Host nicht verfügbar
- `swift test`
  - Ergebnis: 228 Tests, 2 Skips, 0 Failures
- `git diff --check`
  - Ergebnis: sauber

## 5. Gefundene Widersprüche

- aktuelle Truth-Bloecke in mehreren Core-Dokumenten nannten veraltete Teststaende wie `217`, `222`, `224` oder `227`, obwohl der frische Linux-Nachweis jetzt `228 / 2 / 0` ist
- `docs/XCODE_RUNBOOK.md` behauptete am Kopf noch sinngemaess `keine Maps, keine Persistenz, keine Suche, kein Sync`, obwohl Karten, `Days`-Suche, Heatmap, segmentierte `Insights`, lokale Live-Track-Persistenz und optionaler Live-Punkt-Upload real vorhanden sind
- `docs/XCODE_APP_PREPARATION.md` sprach von `offline-only` und `keine Cloud-/Server-Funktionen`, obwohl optionaler nutzergesteuerter Upload real im Code existiert
- `docs/CONTRACT.md` stellte die App-Shell zu stark als `kein Sync, keine Server-/Cloud-Funktionen` dar; fuer den aktuellen Scope stimmt das nur fuer importierte History, nicht fuer optionalen Live-Punkt-Upload
- `NEXT_STEPS.md` enthielt einen geschlossenen Block fuer Apple-CLI-Stabilisierung, obwohl `NEXT_STEPS` laut eigener Governance nur offene Folgearbeit enthalten soll

## 6. Gefundene veraltete Aussagen

- Apple-/Xcode-Nachweise vom 2026-03-30 klangen in README und Checklisten zu praesentisch fuer den aktuellen Repo-Stand
- der Zusatz mit `DEVELOPER_DIR` in `README.md` war nicht klar genug als historischer Apple-Host-Kontext markiert
- offene Apple-Verifikation war teils noch mit Stichtag `2026-03-17` statt gegen den aktuellen Repo-Stand formuliert
- aktuelle Audit-Grenze `xcodebuild nicht auf diesem Host verfuegbar` fehlte in den Kernstellen

## 7. Gefundene fehlende Doku

- frischer Linux-Mindestnachweis vom 2026-03-31 (`swift test`, `git diff --check`) fehlte
- der notwendige neue offene Schritt `frischen Apple-CLI-Gegenlauf fuer den aktuellen konsolidierten Stand nachziehen` fehlte in `NEXT_STEPS.md`
- die Korrektur `offline-first + optionaler nutzergesteuerter Upload` war nicht durchgaengig ueber README, Contract und Xcode-Notizen gezogen

## 8. Konkrete Korrekturen

- `CHANGELOG.md` um Audit-/Doc-Sync-Eintrag ergaenzt
- `README.md` auf frischen Linux-Truth, historische Apple-Nachweise und aktuelle offene Apple-Verifikation umgestellt
- `NEXT_STEPS.md` auf nur noch offene Folgepakete umgeschrieben; neuer offener Apple-CLI-Rerun aufgenommen
- `ROADMAP.md`-Kopfblock auf 2026-03-31 und aktuellen Linux-Truth synchronisiert
- `docs/APPLE_VERIFICATION_CHECKLIST.md` explizit zwischen frischem Linux-Nachweis und historischen Apple-Nachweisen getrennt
- `docs/CONTRACT.md` fuer optionalen Live-Punkt-Upload repo-wahr entschaerft
- `docs/XCODE_APP_PREPARATION.md` und `docs/XCODE_RUNBOOK.md` auf aktuellen Scope und Host-Grenzen korrigiert

## 9. Verbleibende offene Punkte

- kein frischer Apple-CLI-Gegenlauf fuer den aktuellen konsolidierten Stand
- keine frische Apple-UI-Verifikation fuer `Heatmap`, `Live`, `Insights`, `Days`, Upload-Zustaende und Background-Recording
- keine neue Apple-/Review-Einordnung fuer den optionalen Live-Punkt-Upload ueber die korrigierten lokalen Texte hinaus

## 10. Ehrliche Grenzen der Verifikation

- `xcodebuild` ist auf diesem Linux-Host nicht vorhanden
- alle Apple-/Xcode-/Device-Befunde in dieser Audit-Datei bleiben deshalb historische Nachweise aus frueheren Apple-Hosts
- Linux-`swift test` ersetzt keinen Apple-UI-Lauf und keinen neuen Wrapper-/Device-Nachweis

## 11. Abschlussfazit

- Der aktuelle Core-Repo-Truth ist sauber dokumentiert als `offline-first` mit optionalem nutzergesteuertem Live-Punkt-Upload.
- Der frische Host-Nachweis fuer diesen Audit lautet: Linux, Swift 5.9, `swift test` gruen mit `228 / 2 / 0`.
- Die betroffene Core-Doku ist wieder konsistent mit Code, Tests und der auf diesem Host real verfuegbaren Toolchain.
