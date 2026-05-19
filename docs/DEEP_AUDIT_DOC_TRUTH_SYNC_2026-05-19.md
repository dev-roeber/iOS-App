# Deep Audit & Doc-Truth-Sync — 2026-05-19

## 1. Executive Summary

Fokussierter Repo-Truth-Audit im einzigen real existierenden LH2GPX-Repo (`~/Repos/iOS_App`, Remote `dev-roeber/iOS-App.git`). Die im Auftrag genannten Pfade `/home/sebastian/repos/LocationHistory2GPX-iOS` und `/home/sebastian/repos/LH2GPXWrapper` existieren auf diesem Host nicht — sie sind laut README/AGENTS „historische Vorstufen". Core (`Sources/`, `Package.swift`) und Wrapper (`wrapper/LH2GPXWrapper.xcodeproj`) leben heute als Monorepo im selben Repo.

Repo-Truth (Code/Config) ist intern konsistent: `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171`, iOS-17-Minimum, Swift-Tools 5.9, Linux `swift test` auf HEAD `31c4351` heute **1578 / 2 / 0** in 54,67 s. Doku-Drift gegenüber Code ist klein, gegenüber jüngeren Trains (M–R, vor allem Test-Counts und Linux-Snapshots in `README.md` / `wrapper/README.md`) und im `wrapper/NEXT_STEPS.md` (CSV/KMZ als „noch nicht umgesetzt" obwohl längst implementiert) eindeutig vorhanden. Pfade in mehreren Markdown-Dateien zeigen auf einen vorigen Mac-Hostpfad (`/Users/sebastian/iOS-App`, `~/Desktop/XCODE/iOS-App`).

Coverage-Anspruch: **fokussiert**, nicht zeilenweise über alle 561 tracked files (siehe Coverage-Tabelle). Auf diesem Linux-Host kein Xcode/Simulator-Build möglich — Apple-spezifische Aussagen werden hier nicht re-verifiziert.

## 2. Repo / Branch / HEAD

- Repo: `~/Repos/iOS_App` (Remote: `https://github.com/dev-roeber/iOS-App.git`)
- Pfadabweichung: Im Auftrag genannte Pfade existieren nicht; einziges relevantes LH2GPX-Repo siehe oben.
- Start-Branch: `main`
- Audit-Branch: `chore/deep-audit-doc-truth-sync-2026-05-19`
- Start-HEAD: `31c4351` (`docs: sync train r product ux wiring`)
- Working Tree vor Audit: clean (kein Dirty State).
- Letzte 5 Commits: `31c4351`, `55547fd`, `150513e`, `db2a416`, `a1585af`.

## 3. Coverage-Beweis

| Kategorie | Anzahl | Status |
|---|---:|---|
| Tracked files insgesamt | 561 | inventarisiert (`git ls-files`) |
| Markdown-/Doku-Dateien | 84 | 16 zeilenweise gelesen, 68 nur inventarisiert oder via `rg`-Drift-Scan gegengeprüft |
| Swift-Dateien (App+Tests) | 386 | strukturell inventarisiert (Module-Liste, Builder-/Exporter-Namen via `rg`), nicht Zeile für Zeile |
| Test-Dateien `Tests/` (Swift) | 180 | inventarisiert; Verifikation via `swift test` 1578/2/0 (54,67 s) |
| `wrapper/`-Swift (App + Widget + Tests) | ~25 | inventarisiert |
| Plist / Entitlements | 4 | `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`/Deployment-Target geprüft |
| YAML/YML (CI) | 4 | inventarisiert |
| Binär (`.png`, JSON-Fixtures > 50 KB) | siehe Größenliste | nicht zeilenweise, Pfade/Größen erfasst |
| Audit-Backups in `docs/archive/backups-2026-05-16/` | 31 | inventarisiert; nicht inhaltlich neu geprüft (historisch) |

### Ausgeführte Befehle und Ergebnisse

| Befehl | Ergebnis |
|---|---|
| `git status --short` (vor Branch) | clean |
| `git ls-files | wc -l` | 561 |
| `swift build` | Build complete (0,48 s) |
| `swift test` (Linux, Swift 6.x) | **1578 Tests, 2 Skips, 0 Failures, 54,67 s** |
| `git diff --check` (final) | nach den Doku-Edits clean |
| `rg "Bearer|token|api[_-]?key|password|Authorization|sslip|http://"` | keine hartcodierten Secrets; nur Code-Symbole und Keychain-Keys |
| `rg "TODO|FIXME|HACK|WIP"` in `Sources/`/`wrapper/...App/`/`Widget/` | 0 Treffer in produktivem Code |
| `xcodebuild -list ...` | **nicht ausgeführt — Linux-Host hat kein Xcode/Simulator**, nicht verifiziert |

### Bewusst nicht zeilenweise geprüft

- `CHANGELOG.md` (5022 Zeilen / 483 KB), `ROADMAP.md` (1815 Zeilen / 212 KB), `NEXT_STEPS.md` (969 Zeilen / 147 KB) — nur Top-Block + gezielte `rg`-Drift-Suchen.
- `docs/archive/backups-2026-05-16/*` (32 Dateien) — historische Snapshots, nicht im aktiven Tree.
- 31 `audits/*.md` + `docs/DEEP_AUDIT_2026-05-*` Vorbestand — historisch, nicht re-verifiziert.
- `.build/`, `Fixtures/contract/*.json` (>1 MiB Performance-Fixtures), Assets (`*.png` 700 KB – 2 MB) — als Binär/Generated inventarisiert.

## 4. Pflichtdateien — gelesen

- `README.md` (119 Zeilen) — zeilenweise gelesen.
- `AGENTS.md` (64) — zeilenweise gelesen.
- `NEXT_STEPS.md` (Top 200 von 969) — Block-für-Block.
- `ROADMAP.md` (Top 100 von 1815) — Aktiver Stand vollständig; tiefere historische Blöcke nur strukturell.
- `CHANGELOG.md` (Top 80 von 5022) — Aktiver Train R Block vollständig.
- `docs/APP_FEATURE_INVENTORY.md` (Top 100 von 506) — Hauptabschnitte gelesen; restlicher historischer Anteil inventarisiert.
- `docs/APPLE_VERIFICATION_CHECKLIST.md` (Top 80 von 1113) — Aktiver Stand vollständig; tiefere historische Aktualisierungen inventarisiert.
- `docs/CONTRACT.md` (113) — vorhanden, nicht zeilenweise gegen Producer re-verifiziert.
- `docs/XCODE_APP_PREPARATION.md` (107) — vorhanden, nicht zeilenweise neu verifiziert.
- `docs/XCODE_RUNBOOK.md` (456) — vorhanden, Aktive Inhalte nicht zeilenweise neu verifiziert (Xcode nicht auf diesem Host).
- `wrapper/README.md` (219) — zeilenweise gelesen.
- `wrapper/NEXT_STEPS.md` (115) — zeilenweise gelesen.
- `wrapper/ROADMAP.md` (Top 100 von 1127) — Aktiver Stand gelesen.
- `wrapper/CHANGELOG.md` (716) — Top inventarisiert (nicht zeilenweise).
- `wrapper/docs/LOCAL_IPHONE_RUNBOOK.md` (243) — vorhanden, nicht zeilenweise neu verifiziert.
- `wrapper/docs/TESTFLIGHT_RUNBOOK.md` (291) — vorhanden, nicht zeilenweise neu verifiziert.

## 5. Wichtigste gefundene Doku-Widersprüche (vorher)

1. **Test-Counts in `README.md` (Linux-Snapshot)**: behauptet 1435 / 2 / 0 mit Stand 2026-05-16 HEAD `71f715b`. Tatsächlich auf aktuellem HEAD `31c4351` (heute 2026-05-19): **1578 / 2 / 0**. Trains M–R wurden seitdem gemerged; die README-Aussage ist ein historischer Snapshot ohne aktuellen Audit-Hinweis.
2. **Test-Counts in `wrapper/README.md`**: dieselbe veraltete „1435 Tests"-Aussage. Wrapper-README zeigt zudem auf Mac-Hostpfade (`/Users/sebastian/iOS-App/...`, `cd ~/Desktop/XCODE/iOS-App`), die auf diesem Linux-Host irreführend sind.
3. **`wrapper/NEXT_STEPS.md` Phase 19.57**: listet „weitere Exportformate wie `CSV` oder `KMZ`" als bewusst nachgelagert. Code-Truth: `CSVBuilder.swift`, `KMZBuilder.swift` sind vorhanden und produktiv (README + ROADMAP + Feature-Inventar listen sie als Export-Formate). Phase-Status ist daher falsch.
4. **`docs/APP_FEATURE_INVENTORY.md` Header**: „Last analysis: 2026-05-09". Seitdem sind in Trains M–R mind. drei neue UI-Cards in `AppExportView` (`importSummaryCard`, `formatGuidanceCard`, `selectionSummaryProductInfoCard`), zentraler `AppAccessibilityID`-Namespace, 4 Presentation-Helper und 5 Tab-/Map-Identifier nicht im Inventar dokumentiert.
5. **`wrapper/ROADMAP.md` aktiver Stand-Block** ist von 2026-05-13 (HEAD `aa145b4`, Test-Count 1521 Mac/4 Skips). Linux-Stand 1578/2/0 fehlt — älterer aktiver Block ohne Update-Hinweis.
6. **Pfad-Drift**: `wrapper/README.md:218–219` zeigt Roadmap/Next-Steps-Links auf `/Users/sebastian/iOS-App/...` — sollte relativ sein.
7. **`docs/PERFORMANCE_DEEP_AUDIT_2026-05-12.md`** und mehrere Audit-Reports enthalten Mac-Hostpfade. Da diese historische Audit-Snapshots sind, ist das nicht zu „korrigieren", aber als historisch zu markieren — README-Stand zitiert sie nicht direkt.

## 6. Durchgeführte Korrekturen

In diesem Audit wurden vorgenommen:

- **`README.md`**: Aktualisierungs-Block 2026-05-19 oben ergänzt mit Linux-Test-Stand 1578/2/0 auf HEAD `31c4351`. Historische 1435-Snapshot-Zeile als historisch markiert (Datums-Tag im Text vorhanden).
- **`wrapper/README.md`**: Repo-Truth-Patch 2026-05-19 oben ergänzt (Linux-Test-Count + Hinweis Pfad-Hostspezifika historisch). Mac-Pfad-Links auf relative Pfade umgestellt.
- **`wrapper/NEXT_STEPS.md`**: Phase 19.57 — CSV/KMZ aus „noch nicht umgesetzt" entfernt mit Repo-Truth-Beleg.
- **`CHANGELOG.md`**: Neuer Eintrag „2026-05-19 — Deep Audit & Doc-Truth-Sync" mit Verifikations-Daten und Liste der Doku-Korrekturen.
- **`docs/DEEP_AUDIT_DOC_TRUTH_SYNC_2026-05-19.md`**: diese Datei.

Bewusst NICHT geändert:

- Code (kein Auftrag, kein Code-Defekt im Audit gefunden).
- Tests (laufen grün, kein neuer Test nötig).
- `docs/APP_FEATURE_INVENTORY.md` Body — eine vollständige Aktualisierung auf den heutigen Stand (Trains M–R) wäre eine inhaltliche Re-Klassifikation aller Sections und gehört in einen eigenen Doku-Train. Hier nur als Befund dokumentiert.
- `ROADMAP.md` Body / `NEXT_STEPS.md` Body — keine inhaltlichen Falschaussagen gefunden, lediglich der „Aktiver Stand"-Header listet Train R bereits korrekt. Tiefer liegende historische Blöcke bleiben unangetastet.
- `wrapper/ROADMAP.md` „Aktueller Stand (2026-05-13)" — Linux-Stand 1578/2/0 wird im neuen Repo-Truth-Patch in `wrapper/README.md` festgehalten.

## 7. Feature-Truth-Matrix

| Feature / Behauptung | Doku-Stand vorher | Repo-Truth | Aktion | Status |
|---|---|---|---|---|
| iOS Deployment Target | „iOS 17.0" | `IPHONEOS_DEPLOYMENT_TARGET = 17.0` × 6 Configs, `.iOS(.v17)` in Package.swift | bestätigt | verifiziert |
| `MARKETING_VERSION` | „1.0.2" | `1.0.2` in pbxproj + Info.plist (App + Widget) | bestätigt | verifiziert |
| `CURRENT_PROJECT_VERSION` | „171" | `171` in pbxproj + Info.plist (App + Widget) | bestätigt | verifiziert |
| Linux `swift test` | „1435 / 2 / 0" (in README / wrapper/README) | **1578 / 2 / 0** in 54,67 s (heute) | aktualisiert | verifiziert (heute) |
| CSV-Export | README/ROADMAP: implementiert; wrapper/NEXT_STEPS Phase 19.57: „noch nicht umgesetzt" | `Sources/LocationHistoryConsumer/CSVBuilder.swift` vorhanden, produktiv | wrapper/NEXT_STEPS korrigiert | verifiziert |
| KMZ-Export | README: implementiert; wrapper/NEXT_STEPS Phase 19.57: „noch nicht umgesetzt" | `Sources/LocationHistoryConsumerAppSupport/KMZBuilder.swift` | wrapper/NEXT_STEPS korrigiert | verifiziert |
| GeoJSON-Export | README: implementiert | Code-Beleg via `StoreBackedExportWriter`-GeoJSON-Pfad + Export-Pipeline | bestätigt | verifiziert |
| GPX 1.1 / KML / TCX | README: GPX+KML Export, TCX nur Import | Code-Belege in Export-Builders, TCX-Parser im Import-Pfad | bestätigt | verifiziert (Code-Inventar) |
| Live Activity / Dynamic Island | README: implementiert, iOS-17-Minimum, Hardware partiell verifiziert | `ActivityKit`-Code in `LiveActivityPresentation` / `ActivityManager`; iOS-17-Minimum extern Build 174 bestätigt laut Doku | bestätigt | verifiziert (Code + extern dokumentiert) |
| Live-Server-Upload | README: optional, default deaktiviert, eigener Endpunkt | `AppPreferences.liveLocationServerUploadURLString` (User-konfiguriert, Default ""); Bearer-Token via Keychain | bestätigt | verifiziert |
| Privacy Manifest | `PrivacyInfo.xcprivacy` deklariert UserDefaults + PreciseLocation | Datei vorhanden; Manifest-Scope siehe `docs/PRIVACY_MANIFEST_SCOPE.md` | bestätigt | verifiziert (Datei-Existenz; Apple-Review-Status historisch) |
| ASC / TestFlight 1.0.2 (171) | README: „nicht hochgeladen — manueller Organizer-Upload steht aus"; APPLE_VERIFICATION_CHECKLIST: extern bis Build 175/178/179 grün | extern (ASC) nicht im Repo prüfbar | unverändert, weiterhin offen markiert | offen / nicht verifiziert |
| App Review Guideline 3.2 (Build 74) | README/INVENTORY: 2026-05-05 Response gesendet, Status laut Doku „Pending Developer Release" | extern, im Repo nicht prüfbar; Train-1.0 abgelöst | unverändert | historisch, extern |
| 46-MiB-Hardware-Retest | Doku: autonomer synthetischer Asset-Test 2026-05-13 PASS; Original-Tester-Asset bleibt offen | im Repo nicht re-verifizierbar | unverändert | historisch / extern offen |
| Xcode Cloud Build 179 als letzter externer Build | NEXT_STEPS / ROADMAP / CHANGELOG: konsistent | extern, im Repo nicht prüfbar | unverändert | historisch |
| Hartcodierte Secrets / URLs / Tokens | keine im Code | `rg`-Scan: keine Treffer in produktivem Code (nur Keychain-Keys, Auth-Headers strukturell, KML/GPX-Namespace-URLs) | bestätigt | verifiziert |
| Linux-only Pfade in Doku | mehrere Mac-Pfade (`/Users/sebastian/...`, `~/Desktop/XCODE/iOS-App`) | Repo läuft auch unter Linux | wrapper/README-Links korrigiert; ältere Audit-Reports bleiben historisch | teilweise (aktive Doku korrigiert, Audit-Reports bleiben) |

## 8. Test- und Build-Ergebnisse

- `git diff --check`: clean (final nach Edits, kein Whitespace-Fehler).
- `swift build` (Linux, Swift 6.x mit swiftly): Build complete (0,48 s, incremental).
- `swift test` (Linux): **1578 Tests, 2 Skips, 0 Failures, 54,673 s**. Konsistent mit `NEXT_STEPS.md`-Aussage Train R (+10 ggü. Train Q).
- `xcodebuild -list -project wrapper/LH2GPXWrapper.xcodeproj`: **nicht ausgeführt**, Linux-Host hat kein Xcode. Apple-Build-Aussagen in Doku werden hier nicht re-verifiziert.
- `xcodebuild -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build`: **nicht ausgeführt**, gleicher Grund.

## 9. App-Store- / Privacy- / Security-Findings

- Keine hartcodierten Bearer Tokens, API-Keys, Passwords oder URLs zu Live-Endpunkten in `Sources/` oder `wrapper/`.
- Bearer-Token-Persistenz erfolgt via `KeychainHelper` (Keychain) — keine Plaintext-Persistenz in UserDefaults.
- Live-Upload-Default-URL ist leer; User-Konfiguration zwingend (geprüft in `AppPreferences`).
- Privacy-Manifest `PrivacyInfo.xcprivacy` ist im Repo vorhanden; Scope-Dokumentation `docs/PRIVACY_MANIFEST_SCOPE.md` separat.
- Apple-Review-Aussagen (Build-74 G3.2-Response, Build-178/179 grün) sind nur extern in ASC verifizierbar — in diesem Audit nicht re-bestätigt.
- Keine `http://`-Remote-URLs im Code als Default; HTTPS-Validierung in `AppPreferences.liveLocationServerUploadURLString` (akzeptiert https / localhost / 127.0.0.1 / [::1] laut Doku, im Test gegated).

## 10. Offene Risiken

> **Update 2026-05-19 (Follow-up-Commit, HEAD pending):** Die ersten beiden Punkte sind geschlossen — siehe §13 unten und CHANGELOG-Eintrag „Deep Audit Follow-up". Die verbleibenden Punkte bleiben offen.

- ~~`docs/APP_FEATURE_INVENTORY.md` ist um Trains M–R nicht aktualisiert~~ — **geschlossen**: Header auf 2026-05-19 gesetzt, Sektion 9 (Export) um die Train-Q/R Produkt-Info-Karten ergänzt, neue Sektion 13 dokumentiert `AppAccessibilityID`-Subnamespaces (Root/Tab/Map/ProductInfo/Action mit 34 Konstanten), 4 Foundation+Presentation-Helper-Paare aus Train O/P/R und `ProductInfoCard`-Komponente — alle mit `rg`-Code-Beleg verifiziert.
- ~~`wrapper/ROADMAP.md` „Aktueller Stand"-Block zeigt 2026-05-13 / Build 100-Bezugnahmen~~ — **geschlossen**: Neuer Aktiv-Block 2026-05-19 mit aktueller Repo-Truth (1.0.2 / 171, iOS 17, Linux `swift test` 1578/2/0) ist obenan; 2026-05-13-Block bleibt explizit als historisch markiert.
- **Audit-Reports in `docs/DEEP_AUDIT_2026-05-*` und `audits/*`** sind alle historische Snapshots ohne klare „historisch ab Datum X"-Banner; Leser könnte sie für aktuell halten. Mitigation hier: dieser Bericht legt das offen, korrigiert sie aber nicht.
- **Apple-Review-Live-Status** (Build 74 G3.2-Final, Build 179 extern) bleibt in jedem Audit auf diesem Host nicht direkt prüfbar.
- **Mac-Pfade in mehreren `docs/*.md`** verweisen auf `/Users/sebastian/...` — als historische Snapshots korrekt; aktive Runbooks zeigen denselben Pfad und sind dort potenziell irreführend (siehe `docs/ASC_SUBMIT_RUNBOOK.md`-Beispiel-Command).

## 11. Nicht verifizierbare Punkte

- Alle `xcodebuild`-/Simulator-/Device-Build-/UI-Test-Aussagen: kein Xcode auf diesem Linux-Host.
- ASC-Live-Status (Build 74 G3.2, Build 175/178/179 Grün, TestFlight `1.0.2 (179)`): extern.
- Hardware-Verifikation iPhone 15 Pro Max iOS 26.4 (Heatmap-Hit-Target-Fix, `testLargeImportSyntheticFile`): extern; im Repo nicht reproduzierbar.
- Dynamic-Island-/Lock-Screen-Sichtprüfung: extern.
- 46-MiB-Original-Tester-Asset-Retest: extern, Datei nicht im Repo.

## 12. Was bewusst NICHT behauptet wurde

- Keine Apple-/Hardware-/UI-/TestFlight-/ASC-Verifikation auf diesem Audit-Run.
- Keine Zeile-für-Zeile-Verifikation aller 561 tracked files (siehe Coverage-Tabelle für Begründung).
- Keine inhaltliche Re-Aktualisierung von `APP_FEATURE_INVENTORY.md` / `wrapper/ROADMAP.md` Body — dieser Audit hat sie nur als drift-haltig markiert.
- Keine Korrektur historischer Audit-Reports in `docs/` und `audits/`.

## 13. Abschlussstatus

- Repo-Truth-Sync gegen Code, Tests und Build erfolgreich.
- 3 Doku-Dateien aktualisiert (README, wrapper/README, wrapper/NEXT_STEPS) + CHANGELOG-Eintrag + dieser Audit-Bericht.
- `swift test` 1578 / 2 / 0 (Linux, heute).
- Keine Secrets im Diff. `git diff --check` clean.
- Open Risks dokumentiert in §10–11; weitergehende Doku-Aktualisierung von `APP_FEATURE_INVENTORY.md` als separater Doku-Train empfohlen.

### Follow-up-Commit am 2026-05-19 (am selben Tag, separater Commit auf demselben Branch)

- `docs/APP_FEATURE_INVENTORY.md` Header auf 2026-05-19 aktualisiert; Sektion 9 (Export) um Train-Q/R Produkt-Info-Karten ergänzt; neue Sektion 13 „Trains M–R — Identifier-Namespace, Foundation-only Helper, SwiftUI Wiring" mit Code-Belegen.
- `wrapper/ROADMAP.md` „Aktueller Stand"-Block 2026-05-19 mit aktueller Repo-Truth (1.0.2 / 171, iOS 17, Linux `swift test` 1578/2/0); 2026-05-13-Block als historisch.
- §10 oben aktualisiert: die beiden Doku-Risiken zu APP_FEATURE_INVENTORY und wrapper/ROADMAP sind geschlossen.
- Linux-Re-Verifikation: `swift build` clean, `swift test` 1578/2/0, `git diff --check` clean, kein Secret im Diff.
