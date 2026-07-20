# AUDIT iOS State (LocationHistory2GPX-iOS) - 2026-03-31_08-48

## 1. Ziel / Scope

Repo-wahre Statusdokumentation fuer das iOS-App-Repo nach dem vorherigen 4-Repo-Audit. Kein Feature-Batch, keine Code-Aenderung, nur aktuelle Einordnung.

## 2. Gelesene Pflichtdateien

README.md, CHANGELOG.md, ROADMAP.md, NEXT_STEPS.md, docs/APP_FEATURE_INVENTORY.md, docs/CONTRACT.md, docs/APPLE_VERIFICATION_CHECKLIST.md, docs/XCODE_RUNBOOK.md, docs/XCODE_APP_PREPARATION.md, audits/AUDIT_IOS_2026-03-31_08-16.md, audits/AUDIT_4REPO_MASTER_2026-03-31_08-16.md

## 3. Zusaetzlich gepruefte relevante Dateien

Sources/LocationHistoryConsumerAppSupport/LiveLocationServerUploader.swift, Package.swift, .github/workflows/swift-test.yml

## 4. Frisch auf diesem Linux-Host verifiziert

- `swift test` -> 228 Tests, 2 Skips, 0 Failures
- `git status --short --branch` vor Aenderungen sauber
- `git diff --check` wird nach den Doku-Aenderungen erneut geprueft

## 5. Sicher belegter App-Stand

- Days-/Verlaufssicht vorhanden
- Insights / Kennzahlen / segmentierte Insights vorhanden
- Heatmap vorhanden
- Live-Tracking vorhanden
- Upload-Zustaende, Queue- und Failure-Zustaende vorhanden
- Upload-Konfiguration vorhanden
- lokale Suche, Persistenz und Exportpfade vorhanden

## 6. Historisch belegt, nicht frisch auf diesem Host verifiziert

- fruehere Apple-/Xcode-/Device-Laeufe
- fruehere Device-/Simulator-Befunde fuer Wrapper und App-Shell
- fruehere Apple-UI-Befunde fuer Heatmap, Live, Upload und Auto-Restore

## 7. Offene Punkte

- hart kodierter Testendpunkt in `Sources/LocationHistoryConsumerAppSupport/LiveLocationServerUploader.swift`
- Privacy-Manifest-/Upload-Scope nicht final geklaert
- aktueller Apple-/Device-/Simulator-/Review-Endzustand auf diesem Linux-Host nicht frisch verifizierbar

## 8. Konkrete Doku-Korrekturen dieses Laufs

1. README-Rolle auf den realen Stand als eigentliche iOS-Produkt-UI korrigiert
2. README um offene Produktpunkte und Linux-Grenze ergaenzt
3. `NEXT_STEPS.md` fuehrt die Bereinigung der hart kodierten Test-Server-IP jetzt explizit

## 9. Ehrliche Grenzen der Verifikation

- `xcodebuild` ist auf diesem Linux-Host nicht verfuegbar
- keine frische Simulator-Verifikation
- keine frische Device-Verifikation
- `swift test` verifiziert den non-UI-/SwiftPM-Pfad, nicht den gesamten Apple-Endzustand

## 10. Abschlussfazit

Das Repo ist funktional stark ausgebaut und Linux-seitig frisch mit `swift test` bestaetigt. Die staerkste offene Produktabweichung bleibt der hart kodierte Testendpunkt; Apple-/Privacy-/Review-Endzustand bleibt offen.
