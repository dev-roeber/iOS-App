# Deep Audit — 2026-05-12

**Auditor:** Claude Code (Opus 4.7 / 1M)
**Repo:** `dev-roeber/iOS-App` (monorepo, HEAD `ae5de1f`, branch `main`, working tree clean)
**Vorheriger Audit:** `docs/DEEP_AUDIT_2026-05-06.md`
**App-Store-Stand laut User-Screenshots:** ASC zeigt `LH2GPX 1.0.1`, Build **167**, „Bereit für Vertrieb“, manuelle Veröffentlichung.

---

## Executive Summary

- Repo ist auf `main` sauber, HEAD `ae5de1f` „fix: reduce memory peak after large timeline import“ ist gepusht. Keine ungetrackten oder uncommitted Änderungen.
- **Build-Number-Diskrepanz P0**: `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj` führt für alle 8 Build-Konfigs `CURRENT_PROJECT_VERSION = 100`. ASC zeigt laut Screenshots Build **167**. Repo-Truth ≠ ASC-Truth. Build 167 ist **nicht aus diesem Workingtree** ohne Xcode-Cloud-Auto-Increment oder manuellen pbxproj-Bump erzeugbar. Doku (`NEXT_STEPS.md` Line 166, `ROADMAP.md` Line 147, `docs/APPLE_VERIFICATION_CHECKLIST.md` Line 12) sprechen von „Build 100“ — d. h. Doku ist nicht synchron zu ASC.
- **46-MB-Crashfall** bleibt P0 OPEN: zweimal hardwareseitig auf iPhone 15 Pro Max (iOS 26.4) reproduziert (`cd77f97`, `ae5de1f`-Vorzustand). Code-Fix `ae5de1f` adressiert fünf wahrscheinliche Post-Stream-Allokationspfade plus DEBUG-Memory-Probe + Build-Identitäts-Surface. Release-Build-Hardware-Retest steht weiter aus.
- App-Store-Compliance-Profil bleibt günstig: keine Tracking-SDKs, kein `NSUserTrackingUsageDescription`, kein AdSupport/Firebase/Sentry/Mixpanel. Privacy-Manifest (`NSPrivacyTracking=false`, `NSPrivacyCollectedDataTypes=[]`, ein einziger AccessedAPI-Eintrag UserDefaults CA92.1).
- Plaintext-HTTP nur in XML-Namespaces (KML/GPX-Schema-URLs — kein Netzwerkverkehr) und bewusster Localhost-Allowlist (`LiveLocationServerUploader`, kommentiert; `AppPreferences.isLocalhostURL`).
- Keine `fatalError` / `try!` / `as!` / `kCFBooleanTrue!` mehr im Produktivcode unter `Sources/` und `wrapper/LH2GPX{Wrapper,Widget}/` (geprüft per grep, leeres Ergebnis).
- **`swift test` lokal in dieser Session nicht ausführbar**: Sandbox-Restriktion blockiert `xcrun`-Cache-Schreibzugriff auf `/var/folders/.../T/` (`error: permissionDenied`). Letztes im Repo dokumentiertes Ergebnis: `1081/2/0` (HEAD `ae5de1f`, dokumentiert in CHANGELOG/NEXT_STEPS/ROADMAP). Hier nicht reverifiziert.
- **`xcodebuild`-Run / `xcrun devicectl` lokal in dieser Session nicht ausführbar**: gleicher Sandbox-Blocker (`couldn't create cache file …`). Hardware-Retest ist nicht aus dieser Audit-Session triggerbar.
- **Go/No-Go für ASC 1.0.1 Build 167: NO-GO**, solange Sektionen 1–4 des Manual Release Risk Acceptance Protocol leer sind. Reine Code-Korrektheit reicht für Submission nicht.

---

## Repo-Stand

| Feld | Wert |
| --- | --- |
| pwd | `/Users/sebastian/iOS-App` |
| remote | `https://github.com/dev-roeber/iOS-App.git` |
| branch | `main` |
| Start-HEAD | `ae5de1f594f428fbc8a06921a5230c3fde08e610` |
| End-HEAD | `ae5de1f594f428fbc8a06921a5230c3fde08e610` |
| working tree | clean |
| MARKETING_VERSION | `1.0.1` (alle 8 Configs) |
| CURRENT_PROJECT_VERSION | `100` (alle 8 Configs) |
| Bundle | `de.roeber.LH2GPXWrapper` |
| Team | `XAGR3K7XDJ` (laut `docs/APPLE_VERIFICATION_CHECKLIST.md:12`) |

`git log --oneline -10` (siehe Audit-Trace im Conversation-Log) zeigt eine plausible, chronologisch konsistente Commit-Reihe `101e0a4 → … → ae5de1f`.

Sources-Inventar:
- 135 Swift-Files unter `Sources/`
- 89 Swift-Files unter `Tests/`
- Wrapper: 3 Test-Files (`LH2GPXWrapperUITests`, `LH2GPXWrapperUITestsLaunchTests`, `LH2GPXWrapperTests`)
- Hauptmodul `Sources/LocationHistoryConsumerAppSupport/` (~28k LOC, inkl. neue `AppBuildInfo.swift`, `ImportMemoryProbe.swift` aus `ae5de1f`)
- Core `Sources/LocationHistoryConsumer/` mit `Queries/PathDistanceCalculator.swift` (Single-Source-of-Truth Distance, neu seit `853d8d3`)

---

## Geprüfte Dateigruppen

| Gruppe | Methode | Befund |
| --- | --- | --- |
| `wrapper/Config/Info.plist` | Read | OK: `GitCommitSHA = $(GIT_COMMIT_SHA)`-Placeholder vorhanden, `ITSAppUsesNonExemptEncryption=false`, `NSLocationAlways…`/`WhenInUse`-Strings sauber formuliert, `UIBackgroundModes=[location]`, `NSSupportsLiveActivities=true`, lh2gpx-URL-Scheme registriert, Orientierungen iPhone/iPad gesetzt. **Kein `UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace`** — bekannt, bewusst weggelassen. |
| `wrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy` + `wrapper/LH2GPXWidget/PrivacyInfo.xcprivacy` | Read | Beide identisch: `NSPrivacyTracking=false`, `NSPrivacyTrackingDomains=[]`, `NSPrivacyCollectedDataTypes=[]`, ein einziger `NSPrivacyAccessedAPIType` (UserDefaults, Reason `CA92.1`). Compliant mit Apple Required Reasons API. |
| Entitlements (Wrapper + Widget) | Read | Beide nur `com.apple.security.application-groups = [group.de.roeber.LH2GPXWrapper]`. Keine Push, kein iCloud-Container, kein CloudKit, kein HealthKit. Konsistent mit „lokal-only“ Story. |
| Force unwraps (`fatalError`/`try!`/`as!`/`kCFBooleanTrue!`) in `Sources/` + `wrapper/LH2GPX{Wrapper,Widget}/` | grep | Leeres Treffer-Set. P0-2/3/4 aus `DEEP_AUDIT_2026-05-06.md` bleiben behoben. |
| Tracking/Analytics SDKs (`AdSupport`/`FacebookSDK`/`Firebase`/`Mixpanel`/`Sentry`/`NSUserTrackingUsageDescription`) | grep | Keine Treffer in App-Code. Einzige `tracking`-Treffer sind `liveTracking…`-Preferences (= eigene Live-Recording-Feature, nicht Apple-Tracking-Definition). |
| Hardcoded Secrets / Bearer / API_KEY | grep | Kein hardcodeter Bearer/API-Key. Bearer-Token-Pfad ist Nutzereingabe in `AppPreferences.liveLocationServerUploadBearerToken` und wird nur als `Authorization: Bearer <user-token>` in den vom Nutzer konfigurierten Endpoint geschickt. |
| Plaintext-HTTP / Localhost | grep | Nur XML-Namespaces (KML/GPX-Builder, kein Netzwerk-IO) + explizite Localhost-Allowlist in `LiveLocationServerUploader.swift:34-35` und `AppPreferences.swift:330-345` (für Dev-Endpoints). Production-Endpoints werden auf `https://` erzwungen. |
| Plist-DOCTYPE-`http://www.apple.com/DTDs/…` | grep | Standard-Plist-DTD-Reference, kein Netzwerkverkehr. |

---

## App-Store-Connect-Screenshot-Abgleich

Aus den vom User beschriebenen ASC-Screenshots:

| ASC-Feld (Screenshot) | Repo-Truth | Status |
| --- | --- | --- |
| Version 1.0.1 | `MARKETING_VERSION = 1.0.1` (alle Configs) | **MATCH** |
| Build 167 | `CURRENT_PROJECT_VERSION = 100` (alle Configs) | **MISMATCH (P0)** — Repo-Truth ist Build 100, ASC ist Build 167. Build 167 ist im Workingtree nicht reproduzierbar. Doku (NEXT_STEPS Line 166, ROADMAP Line 147, APPLE_VERIFICATION_CHECKLIST Line 12) sind weiter auf „Build 100“ — nicht aktualisiert. |
| Status „Bereit für Vertrieb“ | nicht lokal verifizierbar | nicht lokal prüfbar |
| App Clip: NEIN | kein App-Clip-Target in `wrapper/LH2GPXWrapper.xcodeproj` | **MATCH** |
| iPhone-6,5"-Screenshots | `docs/app-store-assets/` o.ä. vorhanden | nicht im Detail abgeglichen — Pfade existieren, Asset-Truth-Check außerhalb dieses Audits |
| Werbetext / Beschreibung / „Neues in dieser Version“ / Keywords / Support-URL / Review-Notes / DSA | nicht lokal verifizierbar (ASC-Backend) | **nicht lokal prüfbar** |
| Veröffentlichung „manuell“ | nicht lokal verifizierbar | nicht lokal prüfbar |

---

## Build- und Test-Kommandos

| Kommando | Ergebnis | Anmerkung |
| --- | --- | --- |
| `pwd` | `/Users/sebastian/iOS-App` | |
| `git remote -v` / `git branch --show-current` / `git status --short` / `git log --oneline -10` / `git rev-parse HEAD` | sauber, HEAD `ae5de1f`, main, clean | |
| `swift test` | **NICHT AUSFÜHRBAR in dieser Session** | Bash-Sandbox blockiert `xcrun`-Cache-Schreibzugriff (`couldn't create cache file '/var/folders/mx/.../T/xcrun_db-*' (errno=Operation not permitted)`). `dangerouslyDisableSandbox: true` wurde im Dont-Ask-Mode von der Permission-Layer abgelehnt. |
| `xcrun devicectl list devices` | **NICHT AUSFÜHRBAR** | Gleicher Sandbox-Blocker. |
| `xcodebuild` | **NICHT AUSFÜHRBAR** | Gleicher Sandbox-Blocker. |
| grep-/find-/Read-basierte statische Prüfungen | OK | siehe oberer Befundblock. |

**Repo-dokumentiertes letztes Test-Ergebnis (nicht in dieser Session reverifiziert):**
- `swift test`: **1081/2/0** auf HEAD `ae5de1f` (CHANGELOG/NEXT_STEPS/ROADMAP).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED (letztmals in `3811bc3`-Train dokumentiert, nicht für `ae5de1f` reverifiziert).
- UITest-Suite (testAppStoreScreenshots / testDeviceSmokeNavigationAndActions / testLandscapeLayoutSmoke) auf iPhone 15 Pro Max iOS 26.4: PASSED (HEAD `b91a933` zeitlich; `ae5de1f` ist code-seitig dahinter und wurde **nicht** mit voller 3-UITest-Suite reverifiziert).

---

## iPhone-15-Hardware-Ergebnis

Aus dieser Audit-Session **nicht reproduzierbar** — Sandbox blockiert `xcrun`/`devicectl`. Stand laut Repo-Doku (`docs/APPLE_VERIFICATION_CHECKLIST.md` Sektion 1):

- 2026-05-07T13:38:37+02:00: 46-MB-Crashfall iPhone 15 Pro Max iOS 26.4 — **FAILED** (Jetsam-Kill, 232.341 ms). Pre-`cd77f97`.
- 2026-05-07T14:14:36+02:00: **erneut FAILED** trotz Autoreleasepool-Fix `cd77f97` (216.606 ms).
- Post-`ae5de1f` (erweiterter Memory-Fix): **noch nicht hardwareseitig retestet**.
- Sektionen 2 (Live Activity / Dynamic Island / Lock Screen), 3 (iPad-Layout), 4 (ASC / TestFlight / Apple Review) in der Manual-Risk-Checkliste: alle Checkboxen leer, kein Tester-Eintrag.

---

## Befunde nach Priorität

### P0 — Submission-Blocker / Datenverlust / Privacy

- **P0-A — Build-Number-Mismatch Repo ↔ ASC.** `project.pbxproj` führt `CURRENT_PROJECT_VERSION = 100`; ASC zeigt Build 167 als 1.0.1-Submission-Kandidat. Solange dieser Mismatch nicht aufgelöst ist, ist nicht prüfbar, **welcher Code-Stand** in Build 167 steckt — insbesondere, ob `cd77f97`/`ae5de1f` (Memory-Fix-Train) enthalten sind. Mögliche Erklärungen: (i) Xcode Cloud Auto-Increment hat lokal Build 100 als Floor und ASC monoton hochgezählt; (ii) ein lokaler Bump wurde nach `8854eef` weiter erhöht und ist verloren / nicht committet; (iii) `agvtool` o.ä. wurde manuell verwendet. Repo-Truth ist klar Build 100. **Recommended Fix**: vor Submission `git rev-parse HEAD` und `CFBundleVersion` der `.ipa` in ASC vergleichen; wenn Build 167 nicht aus HEAD `ae5de1f` (oder neuer) gebaut ist, **darf Build 167 nicht released werden** — sonst wird ein Stand ohne den vollständigen Memory-Fix veröffentlicht. Nicht im Rahmen dieses Audits korrigiert (kein lokaler Beleg, was 167 enthält).
- **P0-B — 46-MB-Crashfall weiter FAILED.** Status unverändert seit `ae5de1f`-Doku: Release-Build-Hardware-Retest steht aus. **Recommended Fix**: existierender Plan (Memory-Probe + Release-Build-Retest) ist korrekt; dieser Audit fügt nichts hinzu. Solange der Punkt FAILED bleibt, ist die Auslieferung von 1.0.1 als Großimport-fähig nicht behauptbar.

### P1 — schwere UX-/Import-/Device-Bugs

- **P1-A — Doku-Truth-Drift zu ASC-Stand.** `docs/APPLE_VERIFICATION_CHECKLIST.md:12` schreibt „Aktive App-Version: 1.0.1 (Build 100)“, ASC zeigt aber Build 167. Auch `NEXT_STEPS.md` Line 165–173 schreibt von „Xcode Cloud Build ≥100 triggern (Pflicht vor Submit)“ — das wirkt erledigt, ist aber nicht im Repo verankert. **Recommended Fix**: nach Auflösung von P0-A in einem Doku-only-Commit Checklist + NEXT_STEPS auf den real-eingereichten Build-Stand setzen.
- **P1-B — `swift test` Reverifikation für `ae5de1f` in diesem Session-Context nicht möglich.** Sandbox-Restriktion. Außerhalb dieses Audits trivial, durch Tester ausführbar (`swift test` im Terminal liefert direkten Beweis). **Recommended Fix**: keiner für den Audit; einfach im Hostterminal `swift test` ausführen und Ergebnis im PR/CHANGELOG verlinken, falls noch nicht geschehen.
- **P1-C — Volle 3-UITest-Suite nicht für `ae5de1f` reverifiziert.** Letzte vollständige Suite war auf `b91a933`. Zwischen `b91a933` und `ae5de1f` liegen 3 Fix-Commits (`cd77f97`, `ae5de1f` — Memory-Train) plus 1 Doku-Commit (`99a0a6a`). Risiko gering (Code-Änderungen sind defensiv / interne Refactors), aber nicht null. **Recommended Fix**: vor Tag/Release einmal Suite gegen `ae5de1f` fahren.

### P2 — Qualität / Performance / Accessibility / Doku-Widerspruch

- **P2-A — `wrapper/Config/Info.plist` fehlt `UIFileSharingEnabled`/`LSSupportsOpeningDocumentsInPlace`.** Folge: die App ist nicht in der iOS-Files-App sichtbar (was den DEBUG-Memory-Test-Workflow „ZIP im App-Sandbox-Documents ablegen und über Files-Picker importieren“ unbenutzbar macht — entdeckt während des Hardware-Retest-Setups in der vorigen Session). Nicht App-Store-Blocker, aber für den eigentlichen Hardware-Retest-Workflow relevant. **Recommended Fix**: bewusst entscheiden (User-Choice); falls erwünscht, beide Keys auf `true` setzen; dann wird `Documents/` über Files-App sichtbar. Aktuell sind AirDrop/iCloud Drive die einzigen ZIP-Übertragungspfade.
- **P2-B — `docs/ASC_SUBMIT_RUNBOOK.md` referenziert Build 74 als „aktuellster Build“** (Line 17). Veraltet seit 2026-05-05 (Build 74 bewusst nicht released) und insbesondere falsch bezüglich Build 167 in ASC. **Recommended Fix**: Doku-Sync nach Auflösung von P0-A.

### P3 — Polish / Nice-to-have

- **P3-A — Worktree-Leichen.** `~/iOS-App/.claude/worktrees/agent-a1ab18f25be463692/` und `agent-a79169a693d502f5a/` existieren noch (Agent-Worktrees aus Vorsessions, jeweils mit `.build/`-Snapshots). Belegen Plattenplatz, kein funktionaler Impact. **Recommended Fix**: optional `git worktree prune` oder direktes `rm -rf .claude/worktrees/agent-*` — nicht in diesem Audit angetastet (potenziell aktive Agent-State).

---

## Verifiziert (in dieser Session, statisch belegt)

- Repo-Stand (HEAD, Branch, Remote, working tree)
- Versionierungs-String-Konsistenz `MARKETING_VERSION = 1.0.1` über alle 8 Configs
- `CURRENT_PROJECT_VERSION = 100` über alle 8 Configs
- Privacy-Manifest (Wrapper + Widget) Tracking-frei + nur UserDefaults CA92.1 ausgewiesen
- Entitlements (Wrapper + Widget) auf App-Group beschränkt, kein iCloud/CloudKit/HealthKit/Push
- Info.plist-Permissions: nur Location (WhenInUse + AlwaysAndWhenInUse), Background-Mode `location`, Live Activities `true`, `ITSAppUsesNonExemptEncryption=false`, lh2gpx://-Scheme
- Keine `fatalError`/`try!`/`as!`/`kCFBooleanTrue!` in produktivem App-Code
- Keine Tracking-/Analytics-SDKs
- Keine hardcodeten Secrets / Bearer-Token / API-Keys
- HTTP-Verwendung beschränkt auf XML-Namespaces und Localhost-Allowlist
- File-Inventory (135 Source-Files, 89 Tests, 3 Wrapper-Test-Files)

## Nicht verifiziert (in dieser Session, aber prinzipiell lokal prüfbar)

- `swift test` Reverifikation 1081/2/0 für `ae5de1f` (Sandbox blockierte Ausführung)
- `xcodebuild` Wrapper-Build für `ae5de1f`
- 3-UITest-Suite auf iPhone 15 Pro Max für `ae5de1f`
- Hardware-Retest 46-MB-Import auf Release-Build / iPhone 15 Pro Max
- Live Activity / Dynamic Island / Lock-Screen Visual-Check (Manual-Risk-Sektion 2)
- iPad-Layout (Manual-Risk-Sektion 3)
- DEBUG-Memory-Probe (`LH2GPX_IMPORT_MEMORY_LOG=1`) — Soll-Ist-Vergleich

## Nicht lokal prüfbar

- ASC-Backend-Wahrheit: Build 167 echter Inhalt, Status „Bereit für Vertrieb“, Werbetext/Beschreibung/Keywords/Support-URL/Review-Notes/DSA-Anhang
- TestFlight-Build-Liste
- Apple-Review-Historie (Build 74 Pending Developer Release etc.)
- Xcode-Cloud-Build-Logs

---

## Doku-Widersprüche

| Doku-Stelle | Aussage | Realität (lokal) | Empfehlung |
| --- | --- | --- | --- |
| `docs/APPLE_VERIFICATION_CHECKLIST.md:12` | „Build 100“ | ASC zeigt Build 167 | nach P0-A-Auflösung Doku-Sync |
| `NEXT_STEPS.md:14`, :165–:173 | „Xcode Cloud Build ≥100 triggern (Pflicht vor Submit)“ | Build 167 ist offenbar in ASC angekommen | Punkt entweder abhaken oder umformulieren auf 167-Verifikation |
| `docs/ASC_SUBMIT_RUNBOOK.md:17` | „Xcode Cloud aktuellster Build: 74“ | längst überholt | Build-Stand aktualisieren |
| `ROADMAP.md:147` | „CURRENT_PROJECT_VERSION = 100 lokal gesetzt; Xcode Cloud Build ≥100 als nächster ASC-Submit-Kandidat“ | ASC ist bei 167 | Stand aktualisieren |

Dieser Audit nimmt **keine** Doku-Korrekturen vor, weil die zugrundeliegende Frage „was steckt in Build 167?“ nicht lokal beantwortbar ist. Eine Korrektur ohne diesen Beleg würde nur einen neuen Doku-Widerspruch erzeugen.

---

## Roadmap-/Next-Steps-Korrekturen (vorgeschlagen, nicht ausgeführt)

1. P0-A auflösen: Beweise (per `git rev-parse HEAD` zum Zeitpunkt der Archivierung + ipa-Inspektion in ASC), aus welchem Commit Build 167 stammt.
2. Wenn Build 167 = vor `cd77f97`/`ae5de1f`: **Build 167 nicht released**, neuen Build mit `ae5de1f` (oder neuer) hochladen.
3. Wenn Build 167 ≥ `ae5de1f`: 46-MB-Hardware-Retest auf Build-167-Stand + Manual-Risk-Sektionen 1–4 grün machen.
4. Erst dann ASC-Submission triggern.

---

## Datenschutz-/Security-Befund

- **Tracking**: keines. `NSPrivacyTracking=false`, keine SDK-Treffer.
- **Datenfluss**: importierte Standortdaten bleiben lokal (kein iCloud-Container-Entitlement, kein zentraler Server). Optionaler Live-Upload geht an einen vom Nutzer konfigurierten Endpoint (default deaktiviert, `https://`-Zwang außer Localhost). Konsistent mit README/AGENTS-Story.
- **Background-Mode**: nur `location` und nur während aktiver, vom Nutzer manuell gestarteter Live-Aufzeichnung — Usage-Description-Strings benennen das explizit. Apple-Review-tauglich.
- **Secrets**: keine hardcoded. Bearer-Token wird in `AppPreferences` (UserDefaults via App-Group) gespeichert. Hinweis: für höchste Compliance könnte das in Keychain wandern — kein P0, da Bearer-Token explizit Nutzereingabe ist und niemand außer dem User dieses Token kennt. `KeychainHelper` existiert für andere Zwecke.
- **Encryption-Exempt**: `ITSAppUsesNonExemptEncryption=false` ist passend, solange kein Custom-Crypto verwendet wird (nur Standard-`https://` via URLSession). Verifiziert.

---

## Offene Risiken für App Store Review

- Build-Stand-Auflösung (P0-A) — höchste Priorität.
- 46-MB-Crashfall ungelöst — falls Apple-Reviewer mit großer Beispieldatei testet, könnte derselbe Jetsam-Kill auftreten. Großimport wird im Werbetext gerne als „große Google-Timelines“ versprochen — Diskrepanz zwischen Versprechen und realem Verhalten ist ein Guideline-2.1-Risiko.
- Background-Mode `location` + Live-Upload: Apple kann Review-Notes zur Use-Case-Klärung anfordern. Bereits dokumentiert in `docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md`.

---

## Änderungen in dieser Audit-Session

**Keine Codeänderungen.** Keine Doku-Korrekturen außer dem Anlegen dieses Reports (`docs/DEEP_AUDIT_2026-05-12.md`).

Begründung:
- Die zentralen Doku-Widersprüche (Build 100 vs 167) lassen sich nicht ohne externen Beleg (ASC + Archiv-Inspektion) korrigieren — Korrektur ohne Beleg wäre Schönfärbung.
- Code-Befunde liefern keinen klar reproduzierten Bug, der minimal fixbar wäre und in diesem Session-Sandbox-Setup grün testbar wäre.
- Auftragslogik: „Codeänderungen nur, wenn (1) Bug reproduziert, (2) minimaler Fix, (3) Tests grün, (4) Build grün“ — (3)+(4) sind in dieser Session nicht ausführbar.

---

## Abschluss-Status

| Feld | Wert |
| --- | --- |
| Start-HEAD | `ae5de1f594f428fbc8a06921a5230c3fde08e610` |
| End-HEAD | `ae5de1f594f428fbc8a06921a5230c3fde08e610` (unverändert) |
| Commit dieses Audits | nicht erzeugt (kein User-Wunsch zum Commit; Audit-Bericht ist die einzige Deliverable und liegt als untracked File vor) |
| Push-Status | n/a |
| `git diff --check` | n/a (keine Änderung) |
| **Go/No-Go ASC 1.0.1 Build 167** | **NO-GO** bis (a) P0-A geklärt + (b) Manual-Risk-Sektionen 1–4 abgezeichnet |

---

## Anhang — Audit-Method-Limits

Diese Audit-Session lief in Bash-Sandbox-Modus. Folgende erwartete Audit-Aktionen scheiterten an Sandbox-Schreibblockaden auf `/var/folders/.../T/`:
- `swift test`
- `xcodebuild …`
- `xcrun devicectl list devices`
- `xcrun simctl …`

Die statische Audit-Schicht (grep / find / Read der Konfig- und Quellfiles) lief vollständig durch. Für die dynamischen Schichten ist eine Tester-Hand am Terminal nötig (`swift test`, `xcodebuild test` für Wrapper-UITests, `devicectl` für Device-Smoke, manueller 46-MB-Import-Retest).
