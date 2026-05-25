# iCloud-Optionen — Button- und Action-Audit (Prompt 1, 2026-05-25)

> Vollständige Inventur aller interaktiven Elemente in `AppICloudOptionsView.swift` (Status, Phase D.4 + Prompt 1). Audit dient als Single-Source-of-Truth für UI-Reviews, Test-Coverage und zukünftige Refactorings.

## Methodik

Jede interaktive Komponente wird mit folgenden Feldern dokumentiert:

| Feld | Bedeutung |
|---|---|
| **ID** | `accessibilityIdentifier` (Test-Hook) |
| **Pfad** | View-Funktion + Kartenname |
| **Trigger** | Was die Aktion auslöst |
| **Effekt** | Sichtbarer + zustandlicher Effekt |
| **Sichtbarer State** | Was der Nutzer während/nach der Aktion sieht |
| **Failure-Pfad** | Was bei Fehler passiert (Phase D.2/D.3/D.4) |
| **Verifiziert** | Test-Datei + Test-Name |

---

## 1 · Top-Status-Karte

### 1.1 Status-Toggle (oben)
- **ID:** `options.icloud.statusCard`
- **Pfad:** `topStatusCard` → `ICloudStatusCard`
- **Trigger:** `toggleAction` → `preferences.iCloudSyncEnabled.toggle()`
- **Effekt:** Schreibt `iCloudSyncEnabled` in `UserDefaults`; löst `.onChange` aus → `viewModel.setEnabled(newValue)`.
- **Sichtbarer State:** Toggle-Titel wechselt zwischen „iCloud-Sync aktivieren" und „iCloud-Sync deaktivieren". Karten-Farbschema folgt `cardKind(for:healthStatus:)` (Phase D.2-Overload).
- **Failure-Pfad:** keine direkte Failure-Surface; nachgelagerter HealthCheck zeigt CKError im Health-Card.
- **Verifiziert:** `AppPreferencesTests` (iCloudSyncEnabled-Persistenz).

### 1.2 „Status aktualisieren"-Button
- **ID:** `options.icloud.refresh`
- **Pfad:** `body` direkt nach Status-Card
- **Trigger:** `Task { await viewModel.refresh() }`
- **Effekt:** Voller HealthProbe (Account → Write → Read → Delete via `LH2GPXCloudHealthProbe`).
- **Sichtbarer State:** `.disabled(viewModel.status.isWorking)`. AccessibilityHint wechselt während Lauf.
- **Failure-Pfad:** `errorStage` + `ckErrorCodeName` + deutscher Hint im Health-Card (Phase D.2).
- **Verifiziert:** `ICloudHealthStageMappingTests` (Stage-Routing, CKError-Mapping).

---

## 2 · Health-Check-Karte (`healthCheckCard`)

Status-only, keine direkten Buttons — Anzeige der vier HealthProbe-Stages (`accountStatus`/`write`/`read`/`delete`) mit Status-Icons + deutscher Stage-Beschriftung via `germanStageLabel`.

- **Failure-Pfad:** Per-Stage-Icon + CKError-Code-Name + Hint („Production-Schema fehlt"…).
- **Verifiziert:** `ICloudHealthStageMappingTests` (alle 9 Mappings inkl. Phase D.3.1 `invalidArguments`).

---

## 3 · Sicherungs-Auswahl (`iCloudBackupSelectionCard`)

### 3.1 LiveTrack-Metadaten-Toggle
- **ID:** `options.icloud.liveTrackMetadata.toggle` *(falls vorhanden)*
- **Effekt:** `preferences.syncLiveTrackMetadataEnabled`
- **Gate:** Disabled wenn `iCloudSyncEnabled == false` (zusätzlich sichtbarer Hint).
- **Verifiziert:** `AppPreferencesTests`.

### 3.2 Routenpunkt-Toggle
- **Effekt:** `preferences.syncLiveTrackRoutePoints`
- **Sichtbarer State:** Warnhinweis mit `lock.shield` wenn aktiv (Phase D.1).

---

## 4 · Automatisches LiveTrack-Backup (`automaticLiveTrackBackupCard`)

- **Toggle:** `preferences.automaticLiveTrackBackupEnabled`
- **Sichtbarer State:** Gating-Hint sichtbar wenn Sync-Toggle aus.

---

## 5 · Cloud-Datenübersicht (`storageOverviewCard`) — Phase D.4

| ID | Trigger | Sichtbarer State | Failure |
|---|---|---|---|
| `options.icloud.overview.refresh` | `refreshOverview()` | ProgressView + „Aktualisiere…" während Lauf; success → „Übersicht aktualisiert." | `overviewActionFailed=true` + CKError-Hint via `ICloudActionErrorRendering` |
| `options.icloud.backup.retry` *(conditional, nur wenn `pendingBackupCount > 0`)* | `retryPendingBackups()` | ProgressView + „Wiederhole…"; success → „Wartende Sicherungen wiederholt." | wie oben |
| `options.icloud.cloudData.delete` *(conditional, nur wenn Daten existieren)* | `.alert` → `deleteCloudData()` | ProgressView + „Lösche…"; success → „Cloud-Daten gelöscht." | wie oben |

- **Zusatz-Anzeige:** `options.icloud.overview.lastChecked` zeigt `lastCloudKitStatusCheckAt`.
- **Action-Message:** `options.icloud.overview.actionMessage` (Foundation-only renderer).
- **Storage-Error:** `options.icloud.overview.errorMessage` (von `ICloudStorageOverview.errorMessage`).
- **Verifiziert:** `ICloudOverviewActionStateTests` (9 Tests: Success/Failure/Single-Flight/Empty-Pending/CKError-Mapping).

---

## 6 · Statusaktualisierung (`statusAutoRefreshCard`)

- **Toggle:** `options.icloud.autoRefresh.toggle` → `preferences.iCloudStatusAutoRefreshEnabled`
- **Effekt:** `.task` wechselt zwischen `viewModel.refresh()` und `refreshAccountStatusOnly()`.
- **Verifiziert:** `AppPreferencesTests`.

---

## 7 · Netzwerk-Policy (`networkPolicyCard`)

- **Toggle:** `preferences.iCloudAllowCellular` (Standard `false`).
- **Effekt:** `LiveTrackCloudBackupService` respektiert `networkInterfaceProvider`.

---

## 8 · Konfliktbehandlung (`conflictPolicyCard`)

- **Menu-Picker:** `AppICloudSyncConflictPolicy` (Manuell/Lokal/iCloud).
- **HIG-Pattern:** `.menu`-Style (verhindert Abschneiden auf iPhone-SE).

---

## 9 · Container-Info (`containerInfoCard`)

- **Text-only.** Zeigt Container-ID, Privacy-Statement (DE), keine Buttons.

---

## 10 · Datenschutz-Footer

- `LHXInfoCard` mit `lock.shield`. Kein Button.

---

## Audit-Status

| Bereich | Action-States sichtbar | Fehler-Rendering | Test-Coverage |
|---|---|---|---|
| Top-Status | ✅ (D.2) | ✅ (D.2 CKError-Map) | `ICloudHealthStageMappingTests` |
| Health-Card | ✅ (D.2) | ✅ Stage-genau (D.2/D.3.1) | `ICloudHealthStageMappingTests`, `ICloudPerRecordValidationTests` |
| Backup-Auswahl | ⚠ rein Toggle (kein Async-Action) | n/a | `AppPreferencesTests` |
| Auto-LiveTrack | ⚠ rein Toggle | n/a | `AppPreferencesTests` |
| Storage-Overview | ✅ (D.4) | ✅ (D.4 + D.3.1 invalidArguments) | `ICloudOverviewActionStateTests` |
| Auto-Refresh | ⚠ rein Toggle | n/a | `AppPreferencesTests` |
| Netzwerk-Policy | ⚠ rein Toggle | n/a | `AppPreferencesTests` |
| Konflikt-Policy | ⚠ rein Picker | n/a | `AppPreferencesTests` |
| Container-Info | n/a (text-only) | n/a | – |

## Offene Punkte

- **Konflikt-Policy hat keinen Validator-Test.** Empfehlung für Folgephase: Snapshot-Test, dass alle drei `germanShortTitleKey` keine leeren Strings sind.
- **Network-Policy-Toggle hat keinen sichtbaren Action-State** — anders als Storage-Overview-Buttons gibt es nach Toggle-Klick keine direkte Bestätigung. Vertretbar, weil reine Preference; bei TestFlight-Feedback ggf. nachziehen.
- **HealthCheck-Probe respektiert Network-Policy-Toggle aktuell nicht** (Probe läuft auch auf Cellular). Tracken als Folgephase.
