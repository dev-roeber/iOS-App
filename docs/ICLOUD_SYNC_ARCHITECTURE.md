# iCloud Sync Architecture

Stand: **2026-05-22** · zuletzt erweitert auf Branch
`feature/icloud-capability-f1` (Train F.1 — Capability-Vorbereitung).
Ursprung: `docs/APP_REDESIGN_INTERACTION_SPEC_2026-05-22.md` §6.

> **Train F.1 Status:** Entitlement-Datei + CloudKit-Capability-Adapter
> in der Codebase vorbereitet. **Apple Developer Portal noch nicht
> registriert** (`iCloud.de.roeber.LH2GPXWrapper`-Container muss extern
> angelegt werden, bevor ein Mac-Build signiert). Linux `swift build` +
> `swift test` weiter grün (1578/2/0); CloudKit-Code ist `#if
> canImport(CloudKit)`-gegated und fällt auf Linux komplett raus.
> Echter Sync ist **nicht** implementiert — nur `CKAccountStatus`-Adapter.
> Keine Records, keine Subscriptions, keine Assets, keine Historien-
> Synchronisation.

## Ist-Zustand 2026-05-22 (Train F.1)

| Punkt | Status |
|---|---|
| `wrapper/LH2GPXWrapper/LH2GPXWrapper.entitlements` | erweitert um `com.apple.developer.icloud-container-identifiers` + `com.apple.developer.icloud-services = CloudKit` |
| Container-ID | `iCloud.de.roeber.LH2GPXWrapper` (passt zum Bundle-ID, nicht hardcoded für Team) |
| `wrapper/LH2GPXWidget/LH2GPXWidget.entitlements` | unverändert (Widget braucht keinen direkten CloudKit-Zugriff) |
| `CODE_SIGN_ENTITLEMENTS` in pbxproj | unverändert — war bereits korrekt gesetzt |
| `Sources/.../CloudKitCloudSyncService.swift` | NEU, `#if canImport(CloudKit)`-gated, AccountStatus-Adapter, **keine** Records |
| `CloudSyncServiceFactory.makeProductionService(...)` | NEU, wählt CloudKit oder Default automatisch |
| `wrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy` | unverändert (kein neuer Datenfluss, weil keine Records geschrieben werden) |
| Apple Developer Portal Container | **OFFEN** — muss extern angelegt werden, bevor signed Mac-Build möglich |
| AppPreferences `iCloudSyncEnabled` | unverändert (Default `false`, opt-in) |
| Echter Datensync | nicht implementiert (Train F.2) |
| Historien-Sync | weiterhin **explizit ausgeschlossen** |

---

## 1. Entscheidung

**Variante**: *A + C* (iCloud Documents als Export-Hinweis + struktureller
`CloudSyncService` für zukünftige Phase B). **Nicht** *B* in v0.

| Variante | Status v0 | Status v1+ |
|---|---|---|
| A — iCloud Documents (ubiquity container) | als Export-Hinweis vorbereitet; *kein* Capability-Wiring | **Phase C** in Spec |
| B — CloudKit Private Database | Service-Skelett vorhanden, Default-Impl gibt `.disabled` / `.couldNotDetermine` zurück | **Phase B** — eigener Follow-up-Train mit `iCloud.*`-Container, Schema, Konflikt-UX |
| C — Combined | nicht in v0 | später wenn A + B beide live |

**Begründung**: Standortdaten sind extrem sensibel. Eine Public-CloudKit-
Database ist hier *kategorisch ausgeschlossen*. iCloud Documents bietet
den größten unmittelbaren Nutzwert (User-eigene Export-Files in iCloud
Drive sichtbar) ohne neue Datenflüsse. Phase B (CloudKit Private DB) für
Saved-Live-Track-Metadaten kommt erst, wenn die Foundation stabil ist
und ein klarer Multi-Device-Mehrwert ohne Risiko erkennbar ist.

---

## 2. Sicherheitslinie (verbindlich)

1. **Keine Public Database**, weder `CKDatabase.publicCloudDatabase`
   noch `sharedCloudDatabase`.
2. **Lokal-First bleibt Default**. iCloud ist *Komfort*, nicht Pflicht.
   `AppPreferences.iCloudSyncEnabled` ist `false` per Default und nach
   `reset()`.
3. **Kein automatischer Upload importierter Historien**. Die `imports`-
   Tabelle des LocalTimelineStore und der In-Memory-`AppExport` bleiben
   `isExcludedFromBackup = true`. Sie werden nie zu CKAssets oder
   CloudKit-Records.
4. **Keine stillen Uploads**. Jede neue Datenklasse, die iCloud erreicht,
   bekommt einen sichtbaren Settings-Toggle und Opt-in-Text.
5. **Deaktivierbar**. `CloudSyncService.disable()` bringt den Service in
   einen klaren `.disabled`-Zustand zurück; verbliebene lokale Caches
   bleiben unangetastet.
6. **Logging-Verbot**: Koordinaten, Bearer-Token, CloudKit-Record-Names
   oder iCloud-Container-IDs landen *niemals* in Logs.
7. **Account-Status-Resilienz**: `CKAccountStatus.noAccount`,
   `.restricted`, `.couldNotDetermine` und `.temporarilyUnavailable`
   werden in der UI klar kommuniziert; lokale Funktion bleibt
   unverändert.

---

## 2a. Train F.1 — Capability-Vorbereitung (2026-05-22)

Code-/Doku-Änderungen auf Branch `feature/icloud-capability-f1`:

1. `wrapper/LH2GPXWrapper/LH2GPXWrapper.entitlements`
   - `com.apple.developer.icloud-container-identifiers = [iCloud.de.roeber.LH2GPXWrapper]`.
   - `com.apple.developer.icloud-services = [CloudKit]`.
   - **Kein** `com.apple.developer.ubiquity-kvstore-identifier` in dieser
     Phase (Phase-A KV-Store ist laut Spec optional und nicht in v0).
   - **Kein** `com.apple.developer.ubiquity-container-identifiers` (kein
     iCloud-Documents-Container in dieser Phase; Train F.3 / Phase C
     entscheidet später).
2. `Sources/.../CloudKitCloudSyncService.swift` — `#if canImport(CloudKit)`,
   liefert `CKContainer(identifier:)` mit Default
   `iCloud.de.roeber.LH2GPXWrapper`, mapped `CKAccountStatus` →
   `CloudSyncAccountStatus`. **Nur** `accountStatus()`-Call,
   **keine** Record-Operationen, **keine** Subscriptions,
   **keine** Assets, **keine** sharedCloudDatabase, **keine**
   publicCloudDatabase.
3. `Sources/.../CloudSyncService.swift` — neue
   `CloudSyncServiceFactory.makeProductionService(isEnabled:)`:
   - Apple-Plattformen: `CloudKitCloudSyncService`.
   - Linux: `DefaultCloudSyncService` (unverändert, weiter
     `.disabled`/`.couldNotDetermine`).
4. `wrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy` — **unverändert**.
   Begründung: kein Datentyp wird *neu gesammelt*, nur die
   Capability-Erkennung wird über `CKAccountStatus` abgefragt — das
   ist keine Datenerhebung im Sinne von `NSPrivacyCollectedDataTypes`.
   Sobald Train F.2 echte Records schreibt, wird das Manifest erweitert.

### Apple Developer Portal — **noch zu tun** (extern)
- App-ID `de.roeber.LH2GPXWrapper` → Capability "iCloud" → Service
  "CloudKit" zuweisen.
- iCloud-Container `iCloud.de.roeber.LH2GPXWrapper` anlegen, falls noch
  nicht vorhanden.
- Provisioning-Profile regenerieren (Xcode "Automatically manage
  signing" tut das automatisch nach Capability-Aktivierung).

### Linux-Verifikation 2026-05-22
- `swift build` ✅ Build complete.
- `swift test` ✅ 1578 / 2 skipped / 0 failures.
- `xcodebuild` nicht verfügbar (Linux-Host).

## 3. Was dieser Commit liefert

### 3.1 Service-Schicht
`Sources/LocationHistoryConsumerAppSupport/CloudSyncService.swift`:

- `CloudSyncAccountStatus` (`disabled`, `available`, `signedOut`,
  `restricted`, `couldNotDetermine`, `temporarilyUnavailable`, `error(…)`).
- `CloudSyncStatus` (Snapshot mit `accountStatus`, `lastSyncAt`,
  `lastErrorMessage`, `isWorking`).
- `CloudSyncService` Protokoll (`@MainActor`, AnyObject-bound) mit
  `status`, `isEnabled`, `refresh()`, `disable()`.
- `DefaultCloudSyncService` — Foundation-only Default-Impl. Solange die
  Apple-Xcode-Capability nicht aktiv ist, liefert sie `.disabled` bei
  Opt-out und `.couldNotDetermine` bei Opt-in. Ehrlich und Build-stabil.
- `InMemoryCloudSyncService` — deterministische Stub-Implementation für
  Previews und Linux-Tests.

### 3.2 Preferences
`Sources/LocationHistoryConsumerAppSupport/AppPreferences.swift`:

- `iCloudSyncEnabled` — User-Opt-in (Default `false`).
- `preferCloudDriveExport` — UI-Hint im Export-Sheet (Default `false`).
- Beide via `reset()` cleanbar.

### 3.3 UI-Foundation (vorbereitet auf Branch
`chore/full-app-redesign-foundation`)
- `LHXSyncStatusCard` rendert exakt das Mapping aus §3.1 — keine
  Anpassung in *diesem* Commit nötig.

---

## 4. Was dieser Commit NICHT macht

- **Keine** Xcode-Capability-Aktivierung. Diese erfordert:
  - Apple Developer Portal: App-ID `de.roeber.LH2GPXWrapper` mit
    iCloud Service + `iCloud.de.roeber.LH2GPXWrapper`-Container.
  - Xcode → Signing & Capabilities → "+ Capability" → iCloud →
    CloudKit aktivieren, Container auswählen.
  - Generierte Einträge im pbxproj (`SystemCapabilities`) und im
    `LH2GPXWrapper.entitlements`
    (`com.apple.developer.icloud-container-identifiers`,
    `com.apple.developer.icloud-services = CloudKit`,
    `com.apple.developer.ubiquity-container-identifiers`).
- **Keine** Modifikation von `wrapper/LH2GPXWrapper/LH2GPXWrapper.entitlements`.
  Aus Sicherheitsgründen werden Apple-Entitlements ausschließlich in
  Xcode gesetzt, damit pbxproj + Portal + Entitlement-Datei
  konsistent bleiben. Eine partielle Linux-Edit-Änderung würde die App
  möglicherweise unsignierbar machen.
- **Keine** CloudKit-Implementierung (`CKContainer.default()` etc.).
  Die `DefaultCloudSyncService` ist deshalb `couldNotDetermine`/
  `disabled`-only — sie *behauptet* keinen Sync.
- **Keine** Settings-Card-Verdrahtung in `AppOptionsView`.
- **Keine** Privacy-Manifest-Änderungen — sobald CloudKit aktiviert
  wird, muss `PrivacyInfo.xcprivacy` um
  `NSPrivacyAccessedAPICategoryFileTimestamp` (für ubiquity-FS-Calls)
  und ggf. weitere Reasons ergänzt werden. Das passiert im
  Apple-Xcode-Pass.

---

## 5. Folge-Trains (Reihenfolge, Apple-Host-Pflicht)

### Train F.1 — Apple Capability Pass *(Xcode-only)*
1. Container `iCloud.de.roeber.LH2GPXWrapper` im Apple Developer Portal
   anlegen.
2. App-ID `de.roeber.LH2GPXWrapper` mit iCloud Service verbinden.
3. In Xcode: Capability iCloud + CloudKit aktivieren; Container
   selektieren.
4. `wrapper/LH2GPXWrapper/LH2GPXWrapper.entitlements` per Xcode
   automatisch updaten lassen (nicht von Hand).
5. `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`
   `SystemCapabilities`-Block per Xcode-Schreibvorgang anpassen.
6. `xcodebuild` Sim + Device validieren.
7. **Erst dann** Privacy-Manifest aktualisieren und kommitten.

### Train F.2 — CloudKit Adapter
- Neuer Apple-only Code (`#if canImport(CloudKit)`) liefert
  `CloudKitCloudSyncService: CloudSyncService` mit `CKContainer`,
  `accountStatus`, optional `CKQuerySubscription` für Saved-Live-
  Track-Metadaten.
- `LiveTrackMeta`-`CKRecord`-Schema (`schemaVersion: Int`,
  `startedAt`, `endedAt`, `pointCount`, `distanceM`, `sourceFilename`).
- Konfliktstrategie: Last-Write-Wins für Metadaten; `CKAsset`-Anhänge
  nur bei explizitem User-Confirm.

### Train F.3 — Phase C (iCloud Drive Export-Hint)
- UI-Card in `AppExportView`: "Save to iCloud Drive" Toggle bindet
  an `AppPreferences.preferCloudDriveExport`.
- Keine Code-Pfad-Änderung am `fileExporter` selbst — System-Dialog
  bietet iCloud Drive automatisch.

### Train F.4 — Settings-Card-Verdrahtung
- `AppOptionsView` zeigt `LHXSyncStatusCard` mit Live-Bindings gegen
  `CloudSyncService.status`.
- Toggle "Enable iCloud Sync" schreibt
  `AppPreferences.iCloudSyncEnabled` und ruft
  `cloudSyncService.isEnabled = newValue`.

---

## 6. Konfliktstrategie (Phase B Vorbereitung)

Sobald CloudKit-Records geschrieben werden, gilt:

- **Saved-Live-Track-Metadaten**: Last-Write-Wins über
  `CKRecord.modificationDate`. Konflikt-UX zeigt eine `LHXInfoCard`
  (`kind: .warning`) mit "Local vs. Cloud" Diff und manuellem Resolve-
  Button. Kein blindes Überschreiben.
- **Settings (Phase A, optional)**: `NSUbiquitousKeyValueStore` ist
  *eventually consistent*; bei Konflikt gewinnt der lokal aktive Wert
  beim nächsten Userinput. Kein Auto-Merge.
- **Assets**: nur ersetzbar mit User-Confirm.

---

## 7. Privacy-Manifest-Plan (für Train F.1)

| Eintrag | Begründung | Zeitpunkt |
|---|---|---|
| `com.apple.developer.icloud-container-identifiers` | iCloud-Container-Zugriff | Train F.1 |
| `com.apple.developer.icloud-services = CloudKit` | CloudKit-API-Nutzung | Train F.1 |
| `com.apple.developer.ubiquity-container-identifiers` | ubiquity FS für Phase C | Train F.1 |
| `NSPrivacyAccessedAPICategoryFileTimestamp` Reason | URLResourceValues für iCloud-Files | Train F.1 |
| `NSPrivacyAccessedAPICategoryDiskSpace` Reason | Pre-Upload Größenprüfung | falls Phase B Assets schreibt |

`NSPrivacyCollectedDataTypes` bleibt unverändert (`PreciseLocation` für
optionalen Server-Upload), so lange CloudKit nur Metadaten ohne
Koordinaten speichert.

---

## 8. App-Store-Review-Vorbereitung

- Marketing-Description: "Optional iCloud sync for app settings and live-
  track metadata. Imported location histories are *never* uploaded to
  iCloud. No central LH2GPX server. iCloud sync can be disabled at any
  time."
- Demo-Account für Apple Review: nicht nötig (keine Login-Flows).
- Reviewer-Notes: explizit darauf hinweisen, dass iCloud rein Opt-in ist
  und die App komplett lokal funktioniert.

---

## 9. Test-Pflicht (in Train F-Folgekommits)

- Linux Unit-Tests gegen `InMemoryCloudSyncService` (Deterministische
  Status-Übergänge).
- Apple Unit-Tests gegen `DefaultCloudSyncService` (Capability-off-Pfad).
- Apple Integration-Test gegen `CloudKitCloudSyncService` (Train F.2).
- Hardware-Smoke iPhone mit echter iCloud-Anmeldung.

In diesem Commit wurden **keine** Tests gefahren — Foundation soll erst
in einem Apple-Pass kompiliert werden.

---

*Ende der Architektur-Notiz.*
