# AUDIT_HARDMODE_CROSS_REPO_2026-03-31_04-59

## 1. Ziel / Scope

- Cross-Repo-Abgleich zwischen `LocationHistory2GPX-iOS` und `LH2GPXWrapper`
- Wahrheitspruefung von Feature-Scope, Teststatus, Apple-/Device-Wording und offenen Punkten
- Beseitigung dokumentarischer Drift zwischen Core und Wrapper

## 2. Gelesene Pflichtdateien

Core:
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

Wrapper:
- `CHANGELOG.md`
- `README.md`
- `NEXT_STEPS.md`
- `ROADMAP.md`
- `docs/LOCAL_IPHONE_RUNBOOK.md`
- `docs/TESTFLIGHT_RUNBOOK.md`

## 3. Zusätzlich entdeckte relevante Dateien

Core:
- `Package.swift`
- `Package.resolved`
- `.github/workflows/swift-test.yml`
- `scripts/update_contract_fixtures.sh`
- `scripts/run_app_shell_macos.sh`

Wrapper:
- `LH2GPXWrapper.xcodeproj/project.pbxproj`
- `LH2GPXWrapper.xctestplan`
- `Config/Info.plist`
- `LH2GPXWrapper/PrivacyInfo.xcprivacy`
- `LH2GPXWrapper/ContentView.swift`
- `LH2GPXWrapper/LH2GPXWrapperApp.swift`
- `LH2GPXWrapperTests/LH2GPXWrapperTests.swift`
- `LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift`
- `LH2GPXWrapperUITests/LH2GPXWrapperUITestsLaunchTests.swift`

## 4. Ausgeführte Prüfungen / Tests / Befehle

- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS fetch --all --prune`
- `git -C /home/sebastian/repos/LH2GPXWrapper fetch --all --prune`
- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS checkout main && pull --ff-only origin main`
- `git -C /home/sebastian/repos/LH2GPXWrapper checkout main && pull --ff-only origin main`
- `git status --short --branch` in beiden Repos
  - Ergebnis: sauber vor Änderungen
- `swift test` im Core
  - Ergebnis: 228 Tests, 2 Skips, 0 Failures
- `git diff --check` in Core und Wrapper
  - Ergebnis: sauber
- `command -v xcodebuild`
  - Ergebnis: kein Treffer auf diesem Host

## 5. Gefundene Widersprüche

- Wrapper-README/ROADMAP/NEXT_STEPS hingen beim aktuellen Core-Linux-Truth noch auf `217 / 2 / 0`
- Wrapper-NEXT_STEPS hatte noch nicht dieselbe offene Priorisierung wie das Core-Repo; `Live / Upload / Insights / Days` fehlten als eigener oberster Apple-Verifikationsblock
- Wrapper-ROADMAP beschrieb `Server-Upload` noch zu schmal und kannte die spaeteren Queue-/Failure-/Flush-Zustaende nicht im Kopfblock
- Core und Wrapper behandelten historische Apple-Nachweise nicht gleich konsequent als historische Nachweise
- Wrapper-TestFlight-Doku nutzte noch zu starke Begriffe wie `konform` oder implizite Review-Naehe

## 6. Gefundene veraltete Aussagen

- `swift test`-Zahl `217` in Wrapper-README, -ROADMAP und -NEXT_STEPS
- TestFlight-Runbook mit `PrivacyInfo.xcprivacy | konform`
- Runbook- und README-Formulierungen, die den historischen 2026-03-30-Apple-Stand zu sehr wie einen frischen Gegenlauf klingen liessen

## 7. Gefundene fehlende Doku

- frischer Linux-Mindestnachweis `228 / 2 / 0` fehlte im Wrapper komplett
- die Cross-Repo-Harmonisierung fuer `Live`, `Upload`, `Insights`, `Days` und `Heatmap`-Offenstaende fehlte im Wrapper
- der aktuelle Host-Grenzsatz `xcodebuild auf Linux nicht verfuegbar` fehlte in den Wrapper-Runbooks

## 8. Konkrete Korrekturen

- Wrapper-README auf aktuellen Core-Linux-Truth und historischen Apple-Status korrigiert
- Wrapper-NEXT_STEPS in Struktur und Priorisierung an den offenen Core-Truth angeglichen
- Wrapper-ROADMAP-Kopfblock um `Insights / Days UX`, ausgebauten `Live`-Tab und erweiterten Upload-Scope ergänzt
- Wrapper-Runbooks um expliziten Linux-Host-Hinweis und entschaerftes Review-/Privacy-Wording bereinigt
- Core-Doku an denselben historischen Apple-/aktuellen Linux-Truth angeglichen, damit beide Repos denselben Status sprechen

## 9. Verbleibende offene Punkte

- kein frischer Apple-CLI-Rerun fuer Core und Wrapper auf aktuellem Stand
- keine neue Device-Verifikation fuer `Heatmap`, `Live`, `Insights`, `Days`, Upload-Status und Background-Recording
- keine finale Apple-Review-/Privacy-Einordnung fuer den optionalen Live-Punkt-Upload

## 10. Ehrliche Grenzen der Verifikation

- auf diesem Audit-Host fehlt `xcodebuild`
- Wrapper-spezifische Build-/Test-/Device-Aussagen bleiben historische Nachweise
- der Cross-Repo-Abgleich kann auf diesem Host nur den dokumentierten historischen Apple-Stand gegen den aktuellen Code und den frischen Linux-Stand abgleichen

## 11. Abschlussfazit

- Core und Wrapper sprechen nach diesem Audit denselben aktuellen Repo-Truth.
- Der frische belegte Stand ist Linux-only (`swift test` 228/2/0 im Core, `git diff --check` sauber in beiden Repos).
- Alle weitergehenden Apple-/Device-/Review-Themen bleiben explizit offen und werden nicht mehr indirekt als erledigt verkauft.
