# iCloud CloudKit MVP — Phase D (2026-05-25)

## Phase D.1 Polish (2026-05-25, später)

Nach Phase-D-Screenshots wurden in einem Polish-Pass folgende UI-Probleme behoben — **ohne** neue RecordTypes/Sync-Logik:

- Health-Check-Karte: Full-Width-Layout, deutsche „Schreiben/Lesen/Löschen"-Probe, AccountStatus-spezifisches Icon + Farbe, deutsche Fehlerursache-Mapping bei Probe-Fehler (Nicht angemeldet / Netzwerk / Schreib-/Lese-/Löschfehler / Container nicht erreichbar).
- Conflict-Policy-Picker: `.pickerStyle(.segmented)` → `.pickerStyle(.menu)` (Apple-HIG für 3+ Optionen mit Labels > 12 Zeichen).
- `AppICloudSyncConflictPolicy.titleKey`/`captionKey` direkt deutsch, neuer `shortTitleKey`. RawValues `manual`/`preferLocal`/`preferCloud` unverändert.
- Retry-Button-Label kompakt: „Erneut versuchen" + `accessibilityHint`. Disabled `.opacity(0.5)`.
- LiveTrack-Routenpunkte-Toggle: `lock.shield`-Warning-Icon + Sensible-Markierung im Text.
- Backup-Selection-Card: bei deaktiviertem iCloud-Sync sichtbarer Disabled-Grund.
- Container-Privacy: „Öffentliche und geteilte CloudKit-Datenbanken werden nicht verwendet.".

Defaults unverändert konservativ — verifiziert durch `ICloudCloudKitMVPTests.testICloudSettingsDefaultsAreConservative` (9/0).

---

**Start-HEAD:** `734ab8e` · **Phase:** D · **Scope:** iCloud-Seite Deutsch + privater CloudKit-MVP fuer HealthProbe und opt-in LiveTrack-Backups.

## Status

Phase D implementiert einen echten, testbaren CloudKit-MVP:

- Die iCloud-Seite nutzt deutsche sichtbare Texte fuer Status, Toggles, Aktionen, Hinweise und destructive Dialoge.
- `CloudKitICloudHealthCheckService` prueft `CKContainer.accountStatus()` und schreibt/liest/loescht einen nicht-sensiblen Record in `privateCloudDatabase`.
- Der HealthProbe-RecordType ist `LH2GPXCloudHealthProbe` mit `createdAt`, `appBuild`, `schemaVersion`, `randomProbeID`.
- Die Backup-Auswahl ist opt-in und konservativ: LiveTrack-Metadaten, LiveTrack-Routenpunkte, App-Einstellungen und Export-Hinweise sind separat schaltbar; alle sensiblen Optionen bleiben default AUS.
- Automatisches LiveTrack-iCloud-Backup laeuft nur nach explizitem Opt-in, nur nach Abschluss eines neuen LiveTracks und nur fuer LiveTracks, nicht fuer importierte Google-History-Daten.
- `LiveTrackCloudBackupService` persistiert eine retryfaehige Queue in UserDefaults und respektiert die Mobilfunkrichtlinie.
- Die Cloud-Uebersicht zeigt Counts und **geschaetzten** Speicherverbrauch; sie behauptet keine exakte iCloud-Quota.

## CloudKit RecordTypes

| RecordType | Zweck | Felder |
|---|---|---|
| `LH2GPXCloudHealthProbe` | temporaerer Health-Check | `createdAt`, `appBuild`, `schemaVersion`, `randomProbeID` |
| `LH2GPXLiveTrackSummary` | reduzierte LiveTrack-Zusammenfassung | `schemaVersion`, `localTrackIDHash`, `title`, `startedAt`, `endedAt`, `durationSeconds`, `distanceM`, `pointCount`, `hasPointBatches`, `createdAt`, `updatedAt`, `estimatedPayloadBytes` |
| `LH2GPXLiveTrackPointBatch` | Routenpunkt-Batch nur bei explizitem Opt-in | `schemaVersion`, `localTrackIDHash`, `batchIndex`, `batchCount`, `pointCount`, `encodedPointsPayload`, `estimatedPayloadBytes`, `createdAt`, `updatedAt` |

## Privacy-Grenzen

- Private CloudKit Database only.
- Kein `publicCloudDatabase`, kein `sharedCloudDatabase`.
- Kein `CKAsset`, keine `CKSubscription`.
- Keine automatische Import-/Export-Sicherung.
- Keine automatische Google-History-Sicherung.
- LiveTrack-Routenpunkte werden nur bei explizit aktivierter Option in Batches gesichert.
- LiveTrackSummary enthaelt keine Koordinaten.
- Hoehen werden nur uebernommen, wenn `LocationElevationFormatter` echte, vertikal valide Hoehen akzeptiert; keine 0-m-Fallback-Hoehen.
- Logs enthalten keine Koordinaten, Tokens, Team-ID, Pfade oder Raw-Payloads.

## Apple-Doku-Abgleich

Geprueft wurden ausschliesslich offizielle Apple-Quellen:

- CloudKit `CKContainer(identifier:)`, `accountStatus`, `privateCloudDatabase`, `CKRecord`, `CKRecord.ID`, `CKDatabase`, `records(matching:)`, `CKQuery`, `CKError.serverRecordChanged`.
- OSLog/Logger Privacy.
- Core Location Authorization und App Privacy Details fuer Standortdaten.
- Privacy Manifest Files.
- SwiftUI `Form`, `Section`, `Toggle`, `Button`, `confirmationDialog`.

Entscheidung: `privateCloudDatabase` ist korrekt, weil die Records pro Nutzer privat sind. HealthProbe ist nicht sensibel, weil er keine Standortdaten, User-ID, Team-ID, Token, Dateipfade oder Device-ID enthaelt und nach erfolgreichem Test geloescht wird.

## Tests

Neue Tests in `ICloudCloudKitMVPTests` decken ab:

- HealthCheck disabled/success inklusive Write/Read/Delete-Result.
- konservative iCloud-Defaults, Persistenz und Reset.
- Mobilfunkrichtlinie.
- Summary ohne Koordinaten.
- PointBatch nur bei explizitem Opt-in und ohne erfundene Hoehen.
- Queue nur bei Opt-in und Dedupe gleicher Track-ID.
- LiveLocationFeatureModel-Hook nach erfolgreicher lokaler Track-Persistenz.

## Bewusst Nicht Implementiert

- Kein FavoriteEntry-/Favoriten-iCloud-Sync; das ist die nach hinten geschobene Phase E oder spaeter.
- Kein History-/Google-Timeline-Sync.
- Kein Public/shared DB.
- Kein CKAsset/CKSubscription.
- Kein Xcode Cloud, TestFlight, App Review.
- Keine iPad-Build-Setting-Aenderung.
