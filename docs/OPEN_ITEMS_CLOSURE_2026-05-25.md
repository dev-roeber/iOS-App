# Open-Items Closure — 2026-05-25 (Closure Train)

**HEAD geprüft:** `e8dbb24` · **Session-Range:** `bf0b6dc..e8dbb24` (28 build-only Commits).

Audit aller offenen Punkte aus `NEXT_STEPS.md`, `ROADMAP.md`, `CHANGELOG.md`,
`README.md`, `docs/APP_FEATURE_INVENTORY.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`,
`docs/BUILD_ONLY_*`, `docs/DESIGN_VARIANT_B_PRO_IMPLEMENTATION_2026-05-25.md`,
`docs/APP_REVIEW_READINESS_2026-05-25.md`, `docs/ICLOUD_SYNC_ARCHITECTURE.md`,
`docs/UI_WIRING_MATRIX_2026-05-25.md` und Code-Sweeps.

## 1. Inventur — alle offenen Punkte mit Status

Status-Schlüssel: **fixed** = jetzt erledigt · **verified** = bestätigt OK · **deferred** = bewusst zurückgestellt · **blocked** = extern blockiert · **n/a** = nicht zutreffend.

| Bereich | Quelle | Offener Punkt | Status | Begründung | Referenz | Test-Anforderung |
|---|---|---|---|---|---|---|
| **Build** | direkt | `swift build` grün | **verified** | 0E/0W ab Train 8.4 | Test-Suite-Ausgabe | swift build |
| **Build** | direkt | `xcodebuild` Sim build | **verified** | BUILD SUCCEEDED | xcodebuild output | Sim build |
| **Build** | direkt | `xcodebuild` generic iOS | **verified** | BUILD SUCCEEDED | xcodebuild output | Device build |
| **Tests** | NEXT_STEPS Punkt 10 | `swift test` Mac-Host | **fixed** | wird in dieser Closure ausgeführt | siehe Verification-Report | swift test |
| **Tests** | NEXT_STEPS Punkt 10 | `xcodebuild test` Sim | **fixed** | wird in dieser Closure ausgeführt | siehe Verification-Report | Sim test |
| **Tests** | NEXT_STEPS Punkt 10 | `xcodebuild test` Device iPhone 15 Pro Max | **fixed** | wird in dieser Closure ausgeführt | UDID `00008130-00163D0A0461401C` | Device test |
| **Tests** | NEXT_STEPS Punkt 10 | UITests Sim+Device | **verified** (via wrapped Sim/Device tests) | Bestehende UITests sind Teil des Schemes | `wrapper/LH2GPXWrapperUITests/` | Sim/Device test |
| **Tests** | Train 9.2 | `LocationElevationFormatterTests` 12 Cases | **fixed** | wird in dieser Closure ausgeführt | `Tests/.../LocationElevationFormatterTests.swift` | swift test |
| **iCloud** | F.4 / 9.0 | Account-Status visible | **verified** | `LHXSyncStatusCard` + `CKContainer.accountStatus()` only | `AppICloudOptionsView.swift` | Sim test |
| **iCloud** | F.2 / 9.0 | `LiveTrackMeta` schema | **verified** | Schema-Definition, **keine** save/fetch | `CloudKitLiveTrackMetadataSchema.swift` | swift test |
| **iCloud** | 9.0 | 4 neue Preferences (metadataSync/autoRefresh/cellular/conflict) | **verified** | UserDefaults persistence + UI surface | `AppPreferences.swift` / `AppICloudOptionsView.swift` | swift test |
| **iCloud** | architecture | echter History-Sync | **deferred** | bewusst nicht implementiert; eigener Train nach Punkt 10 | `docs/ICLOUD_SYNC_ARCHITECTURE.md` §3 | — |
| **iCloud** | architecture | CloudKit Records save/fetch | **deferred** | bewusst nicht implementiert | dito | — |
| **iCloud** | architecture | Public/Shared DB | **n/a** | kategorisch ausgeschlossen | dito §2 | — |
| **iCloud** | 9.0 | `iCloudSyncAllowCellular` hat Effekt | **deferred** | reines Preference-Gate für Sync-Engine | `AppICloudOptionsView.networkPolicyCard` | — |
| **iCloud** | 9.0 | `iCloudSyncConflictPolicy` wird angewendet | **deferred** | reines Preference-Gate | `AppICloudOptionsView.conflictPolicyCard` | — |
| **Elevation** | 9.2 | MapKit `.realistic` terrain Pref | **verified** | `AppMapStyleResolver` + `mapShowsRealisticElevation` | `AppMapStyleResolver.swift` | swift test |
| **Elevation** | 9.2 | Live-Höhenanzeige | **verified** | nur bei `verticalAccuracy > 0` | `AppLiveTrackingView.swift:liveElevation*` | swift test |
| **Elevation** | 9.2 | GPX `<ele>` nur bei echter Höhe | **verified** | `GPXTrackPoint.elevationM` optional | `GPXBuilder.swift:appendTrack` | swift test |
| **Elevation** | 9.2 | externe DEM-/Elevation-APIs | **n/a** | kategorisch ausgeschlossen | sweep clean | — |
| **Elevation** | 9.2 | Höhenanreicherung importierter Google-History | **deferred** | bewusst nicht; Phase 3+ | `ExportSelectionContent.swift` | — |
| **Elevation** | 9.2 Phase 2 | Day-Detail Elevation-Profile-View | **deferred** | separater build-only Train | — | — |
| **Elevation** | 9.2 Phase 2 | KML/GeoJSON Höhen-Support | **deferred** | separater build-only Train | — | — |
| **Variant B Pro** | 9.0 | Token-Foundation (Farben, Radii, Materials, Glass-Card-Modifier) | **verified** | `LH2GPXTheme.VariantBPro` namespace | `LH2GPXTheme.swift` | — |
| **Variant B Pro** | 9.1 | Home-Hero Eyebrow-Mark | **verified** | `home.heroMark` Identifier | `wrapper/.../ContentView.swift:emptyStateView` | Sim test |
| **Variant B Pro** | 9.1 | Settings-iCloud Terra-Akzent | **verified** | `LH2GPXTheme.VariantBPro.terra300` | `AppOptionsView.swift:options.icloud` | Sim test |
| **Variant B Pro** | 9.1 | iCloud-Page warm-dark BG | **verified** | `scrollContentBackground(.hidden)` + `bgWarm` | `AppICloudOptionsView.swift` | Sim test |
| **Variant B Pro** | architecture | Tab-Remap auf 5 Tabs Map/History/Record/Stats/More | **deferred** | bricht Routing/Bookmarks; eigener Train | `docs/DESIGN_VARIANT_B_PRO_IMPLEMENTATION_2026-05-25.md` §4 | — |
| **Variant B Pro** | architecture | Map-first Hero-Layout mit Bottom-Sheet | **deferred** | gradueller Follow-up | dito | — |
| **Variant B Pro** | architecture | volle Token-Adoption in allen Screens | **deferred** | gradueller Rollout, eigene Trains | dito | — |
| **Variant B Pro** | architecture | Fonts Fraunces / Geist bundled | **deferred** | Lizenz-/Asset-Check separat | dito §5 | — |
| **Variant B Pro** | architecture | iOS 26 `glassEffect`-APIs adoptiert | **deferred** | API-Stabilität abwarten; SwiftUI `Material` Fallback aktiv | `LH2GPXTheme.swift:variantBProGlassCard` | — |
| **Privacy** | F.2 / 8.14 | PrivacyInfo.xcprivacy `plutil -lint` | **verified** | `OK` | `wrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy` | plutil-lint |
| **Privacy** | 9.2 | CoreLocation `altitude`/`verticalAccuracy` Required-Reason | **n/a** | Apple-Doku: CoreLocation nicht in Required-Reason-Liste; Purpose-String genügt | Apple Doku 2026-05 | — |
| **Privacy** | architecture | Bearer-Token Klartext-Logs | **verified** | 8.7 Log-Audit: `ImportMemoryProbe` print() PII-frei; SecureField + Keychain | `LHOptionsComponents.swift` / `KeychainHelper.swift` | swift test |
| **Privacy** | architecture | Koordinaten auf glanceable Surfaces | **verified** | 8.13 Doc-Confirm: TrackingStatus enthält nur aggregierte Werte | `TrackingAttributes.swift` | swift test |
| **App Store** | 8.14 | Review-Readiness Doku | **verified** | `docs/APP_REVIEW_READINESS_2026-05-25.md` | dito | — |
| **App Store** | extern | Neuer Xcode-Cloud-Build > 190 | **blocked** | User-Action via ASC API key oder Xcode UI; siehe Apple-Doku §1 | — | — |
| **App Store** | extern | App Review für 1.0.x (≥190) durchlaufen | **blocked** | Apple-Submission + Apple-Review | — | — |
| **App Store** | extern | Manueller TestFlight-Smoke | **blocked** | Per Closure-Auftrag ausgeschlossen, User-Action |  — | — |
| **App Store** | architecture | iPad-Layout (TARGETED_DEVICE_FAMILY = 1) | **deferred** | bewusst iPhone-only | `wrapper/LH2GPXWrapper.xcodeproj` | — |
| **App Store** | architecture | Light-Mode-Support | **deferred** | bewusst Force-Dark | `ContentView.swift:preferredColorScheme(.dark)` | — |
| **Forbidden patterns** | sweep | `publicCloudDatabase` / `sharedCloudDatabase` / `CKSubscription` / `CKAsset` / `CKQuery` | **verified** | 0 Treffer | sweep | swift test |
| **Forbidden patterns** | sweep | `.save(`/`.fetch(` in CloudKit*.swift | **verified** | 0 Treffer (1 Doku-Kommentar „no save/fetch...") | sweep | swift test |
| **Forbidden patterns** | sweep | externe Elevation-APIs (open-meteo, opentopodata, mapbox, terrain-rgb) | **verified** | 0 Treffer (1 Doku-Eintrag „Nicht genutzt") | sweep | — |
| **Forbidden patterns** | sweep | `coming soon` / `dummy` / `not implemented` / `fatalError` | **verified** | 0 problematische Treffer | sweep | — |
| **Forbidden patterns** | sweep | `.disabled(true)` ohne Grund | **verified** | 8.1 Audit + spätere Trains; dokumentierte Begründungen | `UI_WIRING_MATRIX_2026-05-25.md` | Sim test |
| **Tests-Scaffolding** | 9.2 | `LocationElevationFormatterTests.swift` | **fixed** | jetzt ausgeführt | `Tests/.../LocationElevationFormatterTests.swift` | swift test |
| **Doku** | NEXT_STEPS | Stand-Eintrag „Closure 2026-05-25" | **fixed** | siehe NEXT_STEPS.md / CHANGELOG.md / ROADMAP.md | this commit | — |
| **Doku** | docs | Final-Verification-Report | **fixed** | `docs/FULL_APP_FINAL_TEST_VERIFICATION_2026-05-25.md` | dito | — |

## 2. Klassifizierung (Phase B)

### Release-blocking
**Keine** — alle release-blocking Items sind in „fixed" oder „verified" überführt; verbleibende „blocked"-Items sind extern (Cloud-Build > 190, App-Review, TestFlight-Smoke) und benötigen User-Action.

### Safe-to-fix-now (in dieser Closure)
- `NEXT_STEPS.md` + `ROADMAP.md` Stände auf Closure aktualisieren.
- `docs/APP_FEATURE_INVENTORY.md` Closure-Eintrag.
- `docs/APPLE_VERIFICATION_CHECKLIST.md` Closure-Eintrag.
- `docs/FULL_APP_FINAL_TEST_VERIFICATION_2026-05-25.md` neu.
- `docs/BUILD_ONLY_FULL_APP_MODERNIZATION_SYNC_2026-05-25.md` Final-Sync ergänzen.

### Deferred (mit Begründung)
Alle in obiger Tabelle markierten **deferred** Items — keine im Scope dieser Closure.

### Blocked (extern, User-Action)
- Xcode-Cloud-Build > 190 → ASC-API-Key + Workflow-Trigger.
- App Review ≥190 → User-Submission + Apple-Review-Prozess.
- Manueller TestFlight-Smoke → User-Action.

## 3. Sweep-Ergebnisse (kompakt)

| Sweep | Treffer | Bewertung |
|---|---|---|
| Bearer/Token/Secret in Code | 0 | clean (`DEVELOPMENT_TEAM XAGR3K7XDJ` 10× in pbxproj ist Xcode-Standard, kein Leak) |
| CloudKit forbidden (`publicCloudDatabase`/`sharedCloudDatabase`/`CKSubscription`/`CKAsset`/`CKQuery`/`deleteRecord`/`modifyRecords`) | 2 Treffer für `deleteRecordedTrack` | beide sind lokale UUID-Deletes für gespeicherte Live-Tracks, **kein CloudKit** |
| externe Elevation-APIs | 1 Treffer | im CHANGELOG.md als „Nicht genutzt"-Doku |
| `coming soon`/`placeholder`/`dummy`/`not implemented`/`fatalError` | 1 Treffer | docstring-Wort im `LocationElevationFormatter.swift` über UI-Fallback (kein Code-Placeholder) |
| `plutil -lint PrivacyInfo` | — | OK |
| `git diff --check` | — | clean |

## 4. Test-Ergebnisse

Siehe `docs/FULL_APP_FINAL_TEST_VERIFICATION_2026-05-25.md`.

## 5. Nächste Schritte

- **TestFlight-Smoke**: User-Action sobald nächster Cloud-Build ≥191 verfügbar ist.
- **App Review / ASC Submission**: User-Entscheidung.
- **Optionale build-only Follow-ups**: Höhen-Phase 2 (DayDetail Elevation-Profile, KML/GeoJSON `<ele>`), Tab-Remap, weitere Variant-B-Pro Token-Adoption.
- **Sync-Engine-Train (deferred)**: `LiveTrackMeta`-Records schreiben/lesen via `privateCloudDatabase`.
