# AUDIT 4-Repo Master - 2026-03-31_08-48

## 1. Ziel / Scope

Timestamped Cross-Repo-Status fuer:
- `LocationHistory2GPX`
- `LocationHistory2GPX-iOS`
- `LH2GPXWrapper`
- `lh2gpx-live-receiver`

Nur Doku. Keine Feature-Arbeit, keine Refactorings, keine Produktlogik-Aenderung.

## 2. Host-Realitaet

- Audit-Host: Linux
- `xcodebuild` auf diesem Host nicht vorhanden
- Apple-/Simulator-/Device-/TestFlight-/Review-Endzustand deshalb nicht frisch pruefbar

## 3. Gelesene Pflichtdateien je Repo

### LocationHistory2GPX

- README.md
- CHANGELOG.md
- ROADMAP.md
- NEXT_STEPS.md
- PROJECT_SUMMARY.md
- AUDIT_4REPO_CORE_2026-03-31_08-16.md

### LocationHistory2GPX-iOS

- README.md
- CHANGELOG.md
- ROADMAP.md
- NEXT_STEPS.md
- docs/APP_FEATURE_INVENTORY.md
- docs/CONTRACT.md
- docs/APPLE_VERIFICATION_CHECKLIST.md
- docs/XCODE_RUNBOOK.md
- audits/AUDIT_IOS_2026-03-31_08-16.md

### LH2GPXWrapper

- README.md
- CHANGELOG.md
- ROADMAP.md
- NEXT_STEPS.md
- docs/LOCAL_IPHONE_RUNBOOK.md
- docs/TESTFLIGHT_RUNBOOK.md
- AUDIT_4REPO_WRAPPER_2026-03-31_08-16.md

### lh2gpx-live-receiver

- README.md
- CHANGELOG.md
- docs/API.md
- docs/ARCHITECTURE.md
- docs/DATA_MODEL.md
- docs/OPERATIONS.md
- docs/SECURITY.md
- docs/OPEN_ITEMS.md
- docs/AUDIT_4REPO_RECEIVER_2026-03-31_08-16.md

## 4. Frisch ausgefuehrte Pruefungen in diesem Lauf

- `LocationHistory2GPX`: `python3 -m unittest discover tests` -> 143 Tests, 1 Skip, 0 Failures
- `LocationHistory2GPX-iOS`: `swift test` -> 228 Tests, 2 Skips, 0 Failures
- `lh2gpx-live-receiver`: `.venv/bin/python -m pytest tests/ -q --tb=short` -> 14 Tests, 0 Failures
- `lh2gpx-live-receiver`: `docker compose config` -> valide
- Host-Grenze: `which xcodebuild` -> nicht vorhanden

## 5. Gesamtstatus

- Projekt funktional weit fortgeschritten
- letzter 4-Repo-Abgleich war bereits vorhanden und hat einen echten Doku-Fehler identifiziert und korrigiert
- die Repos bleiben weitgehend konsistent, aber nicht widerspruchsfrei im Sinn von "vollstaendig abgeschlossen"
- Receiver bleibt der am tiefsten betrieblich dokumentierte Baustein; dieser 08-48-Lauf hat jedoch nur Repo-Tests und Compose-Konfiguration frisch bestaetigt, nicht den Live-Smoke wiederholt

## 6. Wichtigste offene Punkte

1. hart kodierte Test-Server-IP im iOS-Code
2. Bearer-Token-Rotation
3. Apple-Device-/Xcode-/Simulator-Verifikation
4. Privacy-Manifest-/Upload-Scope final klaeren
5. App-/Wrapper-Abgleich auf Apple-Umgebung fortsetzen

## 7. Konkrete Doku-Aenderungen dieses Laufs

### LocationHistory2GPX

- README um 4-Repo-Projektkontext ergaenzt
- neue Statusdatei `STATUS_4REPO_2026-03-31_08-48.md`

### LocationHistory2GPX-iOS

- README-Rolle auf den realen Stand als Produkt-UI korrigiert
- `NEXT_STEPS.md` fuehrt die Bereinigung der hart kodierten Test-Server-IP explizit
- neue Statusdatei `audits/AUDIT_IOS_STATE_2026-03-31_08-48.md`

### LH2GPXWrapper

- README und `NEXT_STEPS.md` benennen Testserver-Defaults jetzt ausdruecklich als offenen Produktpunkt
- neue Statusdatei `AUDIT_WRAPPER_STATE_2026-03-31_08-48.md`

### lh2gpx-live-receiver

- README schaerft die Rolle als optionaler Self-Hosted-Baustein ohne Pflicht-Cloud
- `docs/OPEN_ITEMS.md` fuehrt Token-Rotation und appseitige Testserver-/Testtoken-Defaults expliziter
- neue Statusdatei `docs/AUDIT_RECEIVER_STATE_2026-03-31_08-48.md`

## 8. No-Op-Pruefung

- Kein Repo war in diesem Lauf ein No-Op.
- Alle vier Repos benoetigten kleine, sachliche Doku-Ergaenzungen oder neue timestamped Statusdateien.

## 9. Ehrliche Grenzen

- keine neue Apple-/Simulator-/Device-Aussage abgeleitet
- keine neuen Live-Service-Befunde fuer den Receiver erfunden
- keine Secrets, Tokens oder privaten Endpunkte ausgeschrieben

## 10. Abschlussfazit

Der Cross-Repo-Stand ist jetzt sauberer dokumentiert: Rollen, aktueller Gesamtstatus, Verifikationsklassen und offene Risiken sind repo-wahr verteilt. Der naechste echte technische Block bleibt ausserhalb dieser Doku-Arbeit: Apple-Verifikation, Testserver-Bereinigung und Token-Rotation.
