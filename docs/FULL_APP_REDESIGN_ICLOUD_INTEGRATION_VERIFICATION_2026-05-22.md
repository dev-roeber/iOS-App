# Integration Verification — Redesign + UI-Foundation + iCloud-Foundation

Stand: **2026-05-22** · Branch `integration/full-app-redesign-icloud-verify`.

---

## 1. Eingang / Reihenfolge

| Quelle | Branch | HEAD |
|---|---|---|
| Mainline | `main` | `4f0813a` |
| Spec (Doku) | `chore/redesign-interaction-spec` | `e7ea6fb` |
| UI-Foundation | `chore/full-app-redesign-foundation` | `46fc592` |
| iCloud-Foundation | `feature/icloud-sync-foundation` | `b7d1108` |

Merge-Reihenfolge wie vorgegeben:
1. `chore/redesign-interaction-spec` → konfliktfrei.
2. `chore/full-app-redesign-foundation` → **3 Konflikte** (NEXT_STEPS,
   ROADMAP, APP_FEATURE_INVENTORY), minimal aufgelöst.
3. `feature/icloud-sync-foundation` → **5 Konflikte** (CHANGELOG,
   NEXT_STEPS, README, ROADMAP, APP_FEATURE_INVENTORY), minimal
   aufgelöst.

Alle Konflikte waren **Doku-Block-Konflikte** (jeweils zwei „Stand
2026-05-22"-Blöcke mit teilweise überlappendem Inhalt). Auflösungsmuster:
HEAD-Block (kombinierter Integrationsstand) wurde beibehalten; der
einzelne Branch-spezifische Block wurde verworfen, da der HEAD-Block ihn
inhaltlich bereits zusammenfasst. CHANGELOG bekam einen neu formulierten
Integration-Block. Keine Feature-Entscheidung wurde improvisiert.

---

## 2. Hartcheck-Ergebnisse

### 2.1 Git / Whitespace
- `git status --short` clean nach allen Merges.
- `git diff --check` keine Whitespace-Issues.
- `git diff --stat main...HEAD`: 14 Dateien, +1874/-3.

### 2.2 Secret-/PII-Sweep
`rg "Bearer|Token|Authorization|API[-_ ]?Key|Secret|TEAM_ID|DEVELOPMENT_TEAM|178-104|sslip|live-location|password|private key"`
auf dem Diff: alle Treffer sind **Begriffsverwendungen in
Sicherheitslinien-Doku** ("Bearer-Token bleibt im Keychain",
"Logging-Verbot: Koordinaten/Bearer-Header"). **Keine** echten Werte
oder Tokens im Diff. ✅

### 2.3 False-Claim-Sweep
`rg "iCloud.*implemented|CloudKit.*enabled|iPad.*supported|Light Mode.*supported|fully tested|App Store accepted|Build 74 accepted|Public Database|automatic history sync|auto.*sync.*history"`:
- "Keine Public Database" Treffer in `docs/ICLOUD_SYNC_ARCHITECTURE.md`
  und `docs/APP_REDESIGN_INTERACTION_SPEC_2026-05-22.md` sind explizite
  *Negativ*-Aussagen (Anti-Claim). ✅
- "Build 74 accepted" steht ausschließlich in **historischen** Audit-
  Dokumenten (`docs/DEEP_AUDIT_2026-05-06.md`,
  `docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md`), die in diesem
  Integrationsbranch **nicht** angefasst wurden. Historische Snapshots
  werden absichtlich nicht rückwirkend umgeschrieben.
- Keine false iCloud-/iPad-/Light-Mode-/Test-Claims im Diff.

### 2.4 Placeholder-/Dead-UI-Sweep
`rg "TODO|FIXME|dummy|placeholder|coming soon|not implemented|fatalError|preconditionFailure"`
auf neu hinzugefügten Files (`Sources/.../UI/`, `CloudSyncService.swift`):
**0 Treffer.** ✅

### 2.5 Truth-Anker (gezielt)
- `TARGETED_DEVICE_FAMILY = 1;` — **8 Stellen** in
  `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj` (App + Tests + UITests
  + Widget × Debug/Release). iPhone-only. ✅
- `wrapper/LH2GPXWrapper/LH2GPXWrapper.entitlements` enthält **keine**
  `com.apple.developer.icloud-*`-Keys. iCloud nicht aktiviert. ✅
- `wrapper/Config/Info.plist` enthält **kein** `UIUserInterfaceStyle`.
  Force-Dark läuft weiter über `.preferredColorScheme(.dark)` im Code.
  Status weiter „offen" in Doku.

---

## 3. Build / Test

### 3.1 Toolchain
- `swift --version` → **Swift 6.3.2** (`x86_64-unknown-linux-gnu`,
  swiftly-installiert).
- `command -v xcodebuild` → **nicht verfügbar** (Linux-Host).
- iOS-Simulator-Run auf diesem Host **strukturell unmöglich**.

### 3.2 Minor Fix während Verifikation
- Erste `swift build` warf eine Warning über
  `Sources/LocationHistoryConsumerAppSupport/UI/README.md` als unhandled
  file. Fix: `exclude: ["UI/README.md"]` am
  `LocationHistoryConsumerAppSupport`-Target in `Package.swift`. Diese
  Änderung ist die *einzige* Code-Änderung in diesem Integrationspass.

### 3.3 Build
```
$ swift build
Build complete! (2.41s, dann 0.25s nach Package-Fix)
```
**Status: ✅ green.** Eine verbleibende Warning ist Dependency-intern
(`ZIPFoundation/Resources/PrivacyInfo.xcprivacy` als unhandled file —
nicht unsere Verantwortung, ZIPFoundation ist via `.exact()`-Tag gepinnt).

### 3.4 Tests
```
$ swift test
Executed 1578 tests, with 2 tests skipped and 0 failures (0 unexpected)
in 54.85 (54.85) seconds
```
**Status: ✅ 1578/2/0**, identisch zum letzten Doku-Snapshot (1578/2/0 auf
HEAD `549c310`). Neue Komponenten (`LHX*`, `CloudSyncService`,
`AppPreferences`-Erweiterung) sind kompilierbar; bestehende Tests bleiben
grün; **keine neuen Tests in diesem Integrationspass** — die `LHX*`-
Komponenten sind SwiftUI-Views (Apple-Host-Pflicht), die `CloudSyncService`-
Default-Impl ist `disabled`/`couldNotDetermine`-only und braucht erst
in F.2 mit echtem CloudKit-Adapter dedizierte Test-Cases.

### 3.5 Xcode / iOS / Simulator
- `xcodebuild -list -project wrapper/LH2GPXWrapper.xcodeproj` —
  **nicht ausführbar** (Linux).
- `xcodebuild ... build/test -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max'`
  — **nicht ausführbar** (Linux).
- Diese Schritte sind als Apple-Host-Pflicht in
  `docs/APPLE_VERIFICATION_CHECKLIST.md` dokumentiert. Sie sind für
  jeden Merge auf `main` und jede TestFlight-Submission obligatorisch.

#### Empfohlene Apple-Host-Kommandos (für späteren Pass)
```
# Project Listing
xcodebuild -list -project wrapper/LH2GPXWrapper.xcodeproj

# Simulator Build
xcodebuild -scheme LH2GPXWrapper \
  -project wrapper/LH2GPXWrapper.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' \
  build

# Simulator Tests (Unit)
xcodebuild -scheme LH2GPXWrapper \
  -project wrapper/LH2GPXWrapper.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' \
  test

# Device Build (signed Debug)
xcodebuild -scheme LH2GPXWrapper \
  -project wrapper/LH2GPXWrapper.xcodeproj \
  -destination 'id=<deviceUDID>' \
  -allowProvisioningUpdates \
  build

# Xcode Cloud
# (manuell via App Store Connect, Workflow "Release – Archive & TestFlight";
#  letzter extern grüner Build laut README: 179 auf ff789a4)
```

---

## 4. Gezielte Codeprüfung

### 4.1 `Sources/.../UI/LHX*`
- **Kompiliert** zusammen mit dem Rest. ✅
- **Additiv**: keine bestehende View, kein bestehender Identifier
  modifiziert. ✅
- **44 pt Tap-Targets**: `LHXPrimaryActionButton`, `LHXSecondaryActionButton`,
  `LHXMapOverlayControl` setzen explizit `frame(..., minHeight: 44)` bzw.
  `frame(width: 44, height: 44)`. ✅
- **Accessibility**: jede Komponente bietet einen optionalen
  `accessibilityIdentifier`-Parameter und wendet ihn via
  `OptionalAccessibilityIdentifierModifier` an;
  `accessibilityHint(disabledReason)` an Buttons. ✅
- **Keine ungenutzten public APIs ohne Doku**: jede Komponente hat
  einen Header-Kommentar; `Sources/.../UI/README.md` ist Inventar +
  Adoption-Checkliste.

### 4.2 `Sources/.../AppPreferences.swift`
- **Initializer**: `init(userDefaults:)` setzt neu `iCloudSyncEnabled`
  und `preferCloudDriveExport` aus UserDefaults (Default `false`). ✅
- **Reset**: `reset()` entfernt beide UserDefaults-Keys *und* setzt
  beide `@Published`-Properties auf `false`. ✅
- **Codable/Defaults konsistent**: Beide sind reine `Bool` ohne
  Migration; bestehende Stores werden nicht berührt. ✅
- **Keine Migration kaputt**: vorhandene Keys (`distanceUnit`, `startTab`,
  `liveTracking*`, …) sind unverändert. ✅

### 4.3 `Sources/.../CloudSyncService.swift`
- **Foundation-only**: `import Foundation`, **kein** `import CloudKit`,
  **kein** `import SwiftUI`, **kein** `import UIKit`. ✅
- **Default-Impl** liefert `.disabled` (Opt-out) bzw.
  `.couldNotDetermine` (Opt-in ohne aktive Capability) — ehrlich, keine
  Sync-Behauptung. ✅
- **`disable()` idempotent** und setzt Status sauber zurück. ✅
- **Sicherheitslinie** explizit im Klassen-Header dokumentiert.
- **Keine** Public DB, keine automatische Historien-Synchronisation in
  diesem Code (es gibt keinen Sync-Code, *weil* der Apple-Pass fehlt). ✅

### 4.4 iCloud-Doku
- `docs/ICLOUD_SYNC_ARCHITECTURE.md` §5 listet Train F.1 explizit als
  **Apple-Pflicht** (Portal + Capability + Entitlement-Update). ✅
- `docs/APPLE_VERIFICATION_CHECKLIST.md` enthält die exakte Schrittliste
  unter „Aktualisierung 2026-05-22". ✅
- Kein Claim, dass iCloud bereits produktiv funktioniert. ✅

### 4.5 iPad
- `TARGETED_DEVICE_FAMILY = 1` unverändert (8 Stellen). ✅
- README/ROADMAP/NEXT_STEPS sagen explizit „iPhone-only". ✅

### 4.6 Force-Dark / Light
- `UIUserInterfaceStyle` nicht in `Info.plist` deklariert (entscheidung
  steht aus, siehe Spec §1 + Train A).
- Force-Dark läuft per `.preferredColorScheme(.dark)` im Code.
- README/ROADMAP markieren dies als **offenes Risiko**. ✅

---

## 5. Offene Risiken (übernommen aus dem Audit + Spec)

1. **Keine Apple-Host-Verifikation**: SwiftUI-Komponenten und
   AppPreferences-Erweiterung wurden auf Linux *kompiliert*, aber nie
   visuell oder durch `xcodebuild` validiert. Sichtprüfung + Hardware-
   Smoke gehören in Train H.
2. **iCloud-Capability fehlt**: Train F.1 (Apple-Pflicht) bleibt offen.
   Solange sie nicht durchgeführt ist, ist `CloudSyncService`
   *Foundation-only* und liefert keinen echten Sync.
3. **iPad weiterhin nicht freigeschaltet**: Family=1 bleibt; iPad-Smoke
   nicht durchführbar.
4. **Light-Mode-Frage offen**: weder Light noch deklariertes Dark.
5. **LocalTimelineStore** bleibt Spike / default OFF; 46-MiB-Original-
   Asset-Retest weiter offen.
6. **Xcode-Cloud-Build 179 ist letzter extern grüner Build**; alle
   Trains seither (O/P/Q/R + Integration) extern unbestätigt.
7. **App-Review-Status für Build 74** weiter extern, nicht im Repo
   prüfbar.
8. **ZIPFoundation-Warning** (PrivacyInfo unhandled) ist Dependency-
   intern. Upstream-Fix oder Resource-Declaration im Fork wäre der
   saubere Weg; in diesem Pass *nicht* angefasst.

---

## 6. Konkrete nächste Schritte (Reihenfolge laut Spec §10)

### 6.1 Apple-Host-Pflicht (sofort)
1. **`xcodebuild -scheme LH2GPXWrapper build`** auf Mac mit aktuellem
   Integration-HEAD durchziehen — primäre Pflicht-Verifikation, weil
   SwiftUI-View-Compile auf macOS andere Diagnostics produzieren kann
   als Linux.
2. **Xcode Cloud Workflow `Release – Archive & TestFlight`** mit
   diesem Integrations-HEAD oder erst nach Merge auf `main`. Letzter
   extern grüner Build = 179.
3. **TestFlight-Smoke** nach Cloud-Build (Overview/Live/Insights/Export-
   Tabs öffnen, Hero-Map laden).

### 6.2 Train A — Doc-Truth-Sync v3
- README / ROADMAP / NEXT_STEPS auf den Integration-HEAD ziehen, sobald
  er extern geprüft ist.
- iPad-Aussage final (entweder „iPhone-only v1.0.2" zementieren oder
  als nächster Train).
- Light-Mode-Entscheidung dokumentieren.

### 6.3 Train F.1 — Apple Capability Pass (Xcode-only)
Schritte in `docs/ICLOUD_SYNC_ARCHITECTURE.md` §5 und
`docs/APPLE_VERIFICATION_CHECKLIST.md` Aktualisierung 2026-05-22.

### 6.4 Train C — Start/Import/Export UX-Polish
Erste echte Adoption der `LHX*`-Komponenten (Loading-Branch +
Empty-State auf Home-Screen). Niedrigste Risikoschwelle.

---

## 7. Zusammenfassung

- **Integration sauber gemerged**, alle Konflikte minimal in
  Doku-Blöcken aufgelöst.
- **Linux `swift build` ✅**, **`swift test` ✅ 1578/2/0**.
- **Eine Minimal-Codeänderung**: `Package.swift` `exclude: ["UI/README.md"]`.
- **Keine** Apple-Host-Verifikation auf Linux möglich.
- **Keine** Truth-Verschiebung: iPad bleibt iPhone-only, iCloud bleibt
  als Foundation eingecheckt aber nicht aktiviert, Force-Dark bleibt
  undeklariert.
