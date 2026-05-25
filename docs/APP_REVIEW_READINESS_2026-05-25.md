# App Store / Privacy / Review Readiness — 2026-05-25 (Train 8.14)

**HEAD geprüft:** `c9f06b2` · **Scope:** PrivacyInfo + Code-Realität abgleichen, Review-Notes konsolidieren, offene Risiken benennen. **Build-only** — keine Submission, keine Cloud, keine Tests.

## 1. Privacy Manifest gegen Code-Realität

| Manifest-Eintrag | Code-Beleg | Bewertung |
|---|---|---|
| `NSPrivacyTracking = false` | Keine Tracking-Calls, keine Werbe-/Analytics-SDKs | ✅ konsistent |
| `NSPrivacyTrackingDomains = []` | Keine Drittanbieter-Domains kontaktiert | ✅ konsistent |
| `NSPrivacyCollectedDataTypePreciseLocation` (Linked=false, Tracking=false, Purpose=AppFunctionality) | Optionaler `LiveLocationServerUploader` an user-konfigurierten HTTPS-Endpoint; Default `sendsLiveLocationToServer = false`; kein Login, keine Identitäts-Verknüpfung | ✅ konsistent |
| `NSPrivacyAccessedAPICategoryUserDefaults` Reason `CA92.1` | `AppPreferences`, `WidgetDataStore`, `LocalTimelineTechnicalTestSettings` nutzen `UserDefaults.standard` / App-Group-Suite für app-eigene Settings | ✅ konsistent |
| `NSPrivacyAccessedAPICategoryFileTimestamp` Reason `0A2A.1` | `AppContentLoader.swift` (3 Sites: autoRestore size cap, max-supported guard, in-memory import cap) + `GoogleTimelineStoreImporter.swift` (1 Site: total-byte hint) — `FileManager.attributesOfItem(atPath:)` für `.size`-Read gegen user-picker-Dateien | ✅ konsistent (F.2-Erweiterung) |
| `plutil -lint` | `wrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy: OK` | ✅ |

**Keine** weitere `NSPrivacyAccessedAPI`-Kategorie nötig:
- `NSPrivacyAccessedAPICategoryDiskSpace` — nicht genutzt (kein `URLResourceValues` für Volume-Capacity).
- `NSPrivacyAccessedAPICategorySystemBootTime` — nicht genutzt.
- `NSPrivacyAccessedAPICategoryActiveKeyboards` — nicht genutzt.

## 2. iCloud-Capability-Status (F.1–F.4)

| Aspekt | Status | Belegt durch |
|---|---|---|
| Entitlement `com.apple.developer.icloud-container-identifiers = [iCloud.de.roeber.LH2GPXWrapper]` | ✅ aktiv | `wrapper/LH2GPXWrapper/LH2GPXWrapper.entitlements` |
| Entitlement `com.apple.developer.icloud-services = [CloudKit]` | ✅ aktiv | dito |
| Apple Developer Portal Container | ✅ registriert | F.1: Provisioning-Profile mit beiden Keys ausgestellt + Cloud-Distribution-Signing-Pass via Xcode Cloud Build 190 |
| `CloudKitCloudSyncService.swift` (`#if canImport(CloudKit)`-gated) | ✅ aktiv | nur `CKContainer.accountStatus()` — **keine** Records, Subscriptions, Assets |
| `LiveTrackMeta`-Schema (`CloudKitLiveTrackMetadataSchema.swift`) | ✅ definiert | 8 Felder ohne Koordinaten; `recordType = "LiveTrackMeta"`, `schemaVersion = 1`; **keine** save/fetch/query/delete/subscribe |
| Settings → iCloud → `LHXSyncStatusCard` | ✅ wired | `AppICloudOptionsView.swift` |
| Echter Datensync | ❌ nicht implementiert (außerhalb Scope F.x) |
| Historien-Synchronisation | ❌ explizit ausgeschlossen | `docs/ICLOUD_SYNC_ARCHITECTURE.md §2.3` |
| Public / Shared CloudKit DB | ❌ kategorisch ausgeschlossen | dito §2.1 |

## 3. App Store Connect / Review Status

| Item | Status |
|---|---|
| Letzter extern grüner Xcode-Cloud-Build | **190** auf `b25c27d` (F.1, 2026-05-25) |
| TestFlight-Build sichtbar | `LH2GPX 1.0.2 (190)`, 90 Tage verfügbar |
| Vollständiger TestFlight-Smoke (Settings → iCloud-Block-Sichtprüfung, Tab-Wechsel) | ❌ noch nicht durchgeführt |
| App Review für 1.0.x (≥190) | ❌ noch nicht eingereicht |
| Vorherige Review-Akzeptanz | ✅ Guideline 3.2 resolved (siehe `docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md`) |

## 4. Info.plist Purpose Strings

| Key | Wert (Auszug) |
|---|---|
| `NSLocationWhenInUseUsageDescription` | „Your location is used only inside LH2GPX to show your position on the map and to record live tracks you start manually." |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | „Your location is used only inside LH2GPX to continue a live track you started manually, even when the app is no longer in the foreground." |
| `UIBackgroundModes` | `[location]` |

✅ konkret, just-in-time, kein „may be used for…" Schwammigkeit.

## 5. Reviewer-Notes (Kurzvorschlag für nächste Submission)

> **LH2GPX** is a privacy-first, single-user utility for parsing and exporting a user's own Google Maps Timeline data.
>
> **All location data stays on-device by default.** The optional Live Track upload is **off by default** and only sends GPS points to an HTTPS endpoint the user enters manually — there is no central LH2GPX server.
>
> iCloud is opt-in (private database only); the current 1.0.x release ships the CloudKit metadata schema and a visible iCloud status card but **does not yet write records**. No history sync, no public/shared CloudKit database, no advertising, no analytics, no tracking.
>
> Imported files (`app_export.json`, Google Timeline `location-history.json/.zip`, GPX, TCX) stay local and excluded from backup. The user chooses every export destination through the system save sheet — the app never uploads exports automatically.
>
> No login, no account, no organization-bound features (cf. Guideline 3.2 Resolution 2026-05-05).

## 6. DSA / Encryption Disclosure

- **Encryption Export Compliance:** App nutzt nur Standard-iOS-Crypto (HTTPS via `URLSession`, Keychain). Qualifiziert für die ITSAppUsesNonExemptEncryption-Ausnahme; bisheriger Wert in `Info.plist` (falls gesetzt) bleibt unverändert.
- **DSA (EU Digital Services Act):** App ist nicht-kommerziell, kein User-Generated-Content-Sharing, kein Marketplace. Trader-Status ergibt sich aus dem Developer-Account und ist im App Store Connect zu pflegen.

## 7. Offene Risiken (nach 8.0–8.14)

| Risiko | Bewertung | Mitigation |
|---|---|---|
| Vollständige Tests stehen aus (deferred bis Punkt 10) | mittel | Train 10 läuft `swift test`, `xcodebuild test`, UITests, Hardware-Smoke, Xcode Cloud, TestFlight |
| iPad-Layout nicht freigegeben | gering | `TARGETED_DEVICE_FAMILY = 1` (iPhone only) — bewusst, da Layout nicht für iPad geprüft |
| Light Mode nicht freigegeben | gering | `UIUserInterfaceStyle` undeklariert/Force-Dark — bewusst |
| Keine neue TestFlight-Build > 190 | mittel | Punkt 10 erzeugt nächsten Cloud-Build mit Test-Nachaktion |
| App Review für 1.0.x ≥190 noch nicht durchlaufen | mittel | nach Punkt 10 Submission-Entscheidung |

## 8. Pflicht-Anti-Claims (unverändert wahr nach 8.0–8.14)

- ❌ Echter iCloud-Sync implementiert
- ❌ Automatischer Upload aus Import oder Export
- ❌ CloudKit Records save/fetch
- ❌ Historien-Synchronisation aktiv
- ❌ Public / shared Database genutzt
- ❌ CKSubscription / CKAsset / CKQuery genutzt
- ❌ iPad-Layout aktiviert
- ❌ Light Mode unterstützt
- ❌ Neuer Xcode-Cloud-Build / TestFlight-Build verfügbar (> 190)
- ❌ App Review für 1.0.2 (190) bestanden / eingereicht
- ❌ Bearer-Token in Klartext-Logs
- ❌ Koordinaten in Logs / Widget / Dynamic Island

## 9. Nächster Schritt

**Train 8.15 — Final Build-only Consolidation** (final report 8.0–8.14), dann **Punkt 10 — Vollständige Tests / Xcode Cloud / TestFlight**.
