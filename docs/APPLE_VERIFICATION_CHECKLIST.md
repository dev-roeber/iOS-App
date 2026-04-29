# Apple Verification Checklist

## Zweck

Diese Checkliste trennt klar zwischen:

- bereits real verifizierten Apple-Schritten
- noch offenen interaktiven UI-Schritten

Sie gilt fuer die produktnahe App-Shell `LocationHistoryConsumerApp`.

---

## TestFlight-Smoke-Test-Kriterien vor App-Store-Submission

Mindestanforderungen, die vor einer App-Store-Einreichung auf einem echten iPhone erfüllt sein müssen:

### Blocking (muss grün sein)
- [ ] App installiert sich ohne Fehler aus TestFlight
- [ ] App startet ohne Crash auf Zielgerät
- [ ] Dateiimport (`.json`/`.zip`) funktioniert und zeigt Daten an
- [ ] Overview, Days, Insights, Export, Live-Tab sind navigierbar ohne Crash
- [ ] Kein reproduzierbarer Crash in den Hauptflows

### Performance-Schwellenwert (vor Submission bewerten)
- [ ] Performance-Smoke-Test mit großem Datensatz (>20 MB reale Location-History) abgeschlossen
- [ ] Keine UI-Hänger >2–3 Sekunden auf dem Zielpfad (Import → Overview-Karte laden → Days-Tab)
- [ ] Jeder reproduzierbare Hänger mit Screen/Flow dokumentiert und priorisiert

### Beobachtung Build 1.0 (44) — Stand 2026-04-29
- **TestFlight-Verfügbarkeit**: Build 1.0 (44) ist auf iPhone installierbar ✅
- **Interner Smoke-Test**: App startet, Haupttabs navigierbar, kein bestätigter Crash ✅
- **Performance**: gelegentliche UI-Hänger/Ruckler beobachtet — kein reproduzierbarer Crash, aber noch kein systematischer Großdaten-Test
- **Overview-Map Freeze-Blocker**: behoben (Hard Overlay Limit, s. CHANGELOG 2026-04-29); Performance-Audit bestätigt: kein globales Coordinate-Budget nötig; `overlayLimit × maxPolylinePoints` schützt implizit (max 9.600–48.000 Koordinaten je Tier); TestFlight-Verifikation mit echten großen Daten noch ausstehend
- **App-Store-Submission**: noch nicht eingereicht ❌ (offen bis Fix auf TestFlight mit echten Daten verifiziert + Build in App Store Connect unter Vertrieb ausgewählt + eingereicht)

---

## Statusstand 2026-04-29 — App-Store-Screenshots (iPhone 15 Pro Max)

### Verifikation 2026-04-29 — Screenshots

Ausgefuehrt auf: iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C), Xcode 26.3

#### ✅ real verifiziert (2026-04-29) — Screenshot-Set

- **UITest `testAppStoreScreenshots`** auf iPhone 15 Pro Max: PASSED (41 s), 6/6 Screenshots erzeugt
- **Screenshot-Verfahren**: XCTAttachment → xcresult-Bundle → xcresulttool-Extraktion → sips-Skalierung
- **Originale**: `docs/app-store-assets/screenshots/iphone-67/` — 1290×2796 px (native iPhone 15 Pro Max 3×)
- **App Store 6.5"**: `docs/app-store-assets/screenshots/iphone-65/` — 1242×2688 px (proportional skaliert + 3 px Crop)
- **Inhalt**: Demo-Daten (synthetische Fixture aus dem Repo — keine privaten Nutzerdaten)
- **Keine privaten Daten**: ausschließlich Repo-Demo-Fixture verwendet, keine echten Standortdaten
- **Keine feste Server-URL**: Live-Tab zeigt nur optionalen/nutzergesteuerten Upload-Screen (kein Entwickler-Server)
- **Keine Debug-Overlays**: saubere UI ohne Developer-Tools
- **App-Store-Deklaration**: „Keine Daten erfasst" korrekt
- **iPad**: v1 jetzt iPhone-only (`TARGETED_DEVICE_FAMILY = 1`) — kein iPad-Support im Release-Build vorgesehen
- **Apple Watch**: keine WatchKit-App im Repo — keine Watch-Screenshots nötig

#### ScreenShot-Dateien (für App Store Connect)

| Datei | Größe | Slot |
|-------|-------|------|
| `iphone-67/01-import.png` | 1290×2796 | iPhone 6.7" (bevorzugt) |
| `iphone-67/02-overview-map.png` | 1290×2796 | iPhone 6.7" (bevorzugt) |
| `iphone-67/03-days.png` | 1290×2796 | iPhone 6.7" (bevorzugt) |
| `iphone-67/04-insights.png` | 1290×2796 | iPhone 6.7" (bevorzugt) |
| `iphone-67/05-export.png` | 1290×2796 | iPhone 6.7" (bevorzugt) |
| `iphone-67/06-live-recording.png` | 1290×2796 | iPhone 6.7" (bevorzugt) |
| `iphone-65/01-import.png` | 1242×2688 | iPhone 6.5" |
| `iphone-65/02-overview-map.png` | 1242×2688 | iPhone 6.5" |
| `iphone-65/03-days.png` | 1242×2688 | iPhone 6.5" |
| `iphone-65/04-insights.png` | 1242×2688 | iPhone 6.5" |
| `iphone-65/05-export.png` | 1242×2688 | iPhone 6.5" |
| `iphone-65/06-live-recording.png` | 1242×2688 | iPhone 6.5" |

**Empfehlung**: Upload der `iphone-67/`-Dateien (1290×2796) in den "6.7-inch Display"-Slot von App Store Connect. Dieser Slot dient gleichzeitig als Fallback für 6.5-inch-Geräte.

---

## Statusstand 2026-04-29 — Verifikationsrunde (MacBook, Xcode 26.3, iPhone 15 Pro Max)

### Verifikation 2026-04-29

Ausgefuehrt auf: macOS, Xcode 26.3, iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C)

#### ✅ real verifiziert (2026-04-29)

- **swift test**: 643 Tests, 0 Failures, 0 Skips — bestätigt (2× gelaufen)
- **xcodebuild generic/platform=iOS (LH2GPXWrapper)**: BUILD SUCCEEDED — Wrapper inkl. Widget
- **xcodebuild platform=macOS (LocationHistoryConsumerApp)**: BUILD SUCCEEDED
- **CI.xctestplan Wrapper-Unit-Tests** (iPhone 17 Pro Max Simulator, iOS 26.3.1, testPlan CI): TEST SUCCEEDED — alle LH2GPXWrapperTests grün
- **UITests alle 6 Tests auf iPhone 15 Pro Max** (00008130-00163D0A0461401C, ios 26.3): 6/6 PASSED ✅
  - `testLaunch` × 4 — App startet sauber, kein Crash ✅
  - `testAppStoreScreenshots` — Demo-Daten laden, Day-Liste sichtbar ✅
  - `testDeviceSmokeNavigationAndActions` (55s) — vollständiger Smoke-Pfad ✅:
    - Demo Data geladen, Overview-Tab erscheint ✅
    - All-Time-Filter-Chip (`range.chip.all`) sichtbar und tappbar ✅ (neu: accessibility identifier)
    - Heatmap-Sheet öffnet und schließt ✅
    - Insights-Tab: `insights.section.share` Button gefunden, Share-Popup erscheint ✅
    - Export-Tab: fileExporter auf echtem Gerät ausgelöst ✅
    - Live-Tab: Start-Recording, Location-Permission-Dialog, Stop-Recording — alles auf echtem Gerät ✅
- **Info.plist**: NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription, UIBackgroundModes=location, NSSupportsLiveActivities=true — vorhanden und korrekt
- **Entitlements**: App Group `group.de.roeber.LH2GPXWrapper` in App + Widget Entitlements — korrekt
- **PrivacyInfo.xcprivacy**: NSPrivacyTracking=false, UserDefaults CA92.1, NSPrivacyCollectedDataTypePreciseLocation — vollständig
- **Export-Compliance**: `ITSAppUsesNonExemptEncryption = false` in `wrapper/Config/Info.plist` (App) und `wrapper/LH2GPXWidget/Info.plist` (Widget) gesetzt — kein Upload-Dokument nötig. Begründung: App nutzt ausschließlich systemseitige HTTPS/TLS (URLSession, optionaler Live-Location-Upload); keine eigene Verschlüsselung (kein CryptoKit, CommonCrypto, AES, RSA, VPN, E2E-Messaging, Crypto-Bibliotheken).
- **Release-Signing-Konfiguration**: `LH2GPXWrapper` + `LH2GPXWidget` auf `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM = XAGR3K7XDJ`, `"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution"` in beiden Release-Configs, Buildnummer `28`; keine feste `PROVISIONING_PROFILE_SPECIFIER`; `com.apple.ApplicationGroups` in TargetAttributes für App + Widget
- **Widget-Embed**: `LH2GPXWidget.appex` wird mit `CodeSignOnCopy` eingebettet
- **Sicherheit**: keine hartcodierten Tokens/Secrets; defaultTestEndpointURLString=""; HTTPS fuer non-localhost erzwungen; Bearer-Token via Keychain
- **Deployment Target**: iOS 16.0 (App, LH2GPXWrapperTests) / 16.2 (Widget, UITests) — verifiziert in project.pbxproj
- **Bundle IDs**: de.roeber.LH2GPXWrapper / de.roeber.LH2GPXWrapper.Widget / de.roeber.LH2GPXWrapperTests / de.roeber.LH2GPXWrapper.UITests — korrekt
- **ZIPFoundation**: Fork dev-roeber/ZIPFoundation, Tag 0.9.20-devroeber.1, .exact() — gepinnt
- **ci_scripts**: ci_post_clone.sh, ci_pre_xcodebuild.sh, ci_post_xcodebuild.sh — ausführbar, korrekte Xcode-Cloud-Namen
- **.xcode-version**: 26.3 — gepinnt
- **Bug-Fix**: `AppHistoryDateRangeControl` — `.accessibilityIdentifier("range.chip.\(preset.rawValue)")` ergänzt (ermöglicht UITest-Selektion des All-Time-Chips ohne Sprachabhängigkeit)
- **UITest-Fix**: `testDeviceSmokeNavigationAndActions` — tappt nach Demo-Load `range.chip.all` um Last-7-Days-Filter zurückzusetzen; Demo-Daten (2024) sonst durch Default-Filter unsichtbar

#### ⚠️ nicht automatisiert prüfbar (erfordern manuellen Device-Durchgang)

- **Großer Import (>20 MB)**: kein 46-MB-Fixture im Repo; manuell mit echter Location-History-Datei prüfen
- **Days-Tab**: Day-Detail + Day-Map auf Gerät interaktiv prüfen (im UITest nur als Demo-Nebeneffekt belegt)
- **Historien-Track-Editor**: Route entfernen, App-Neustart, Mutation prüfen — nicht automatisiert prüfbar
- **Widget auf Homescreen/Lockscreen**: Widget Target baut, aber Pinnbar-Test erfordert manuelle Homescreen-Interaktion
- **Live Activity / Dynamic Island**: NSSupportsLiveActivities=true, Code vorhanden, manueller Real-Nachweis noch offen
- **Landscape auf allen Tabs**: kompaktes Landscape-Layout nicht systematisch auf Device verifiziert

#### ❌ weiterhin offen (aktualisiert 2026-04-29, Root Cause bewiesen)

- **Xcode Cloud Build 34 – Root Cause: NFD/NFC-Normalisierungsmismatch in Designated Requirement**

  Vollständige IPA-Forensik (IPA: `LH2GPXWrapper 1.0 app-store-4`, Build 34) ergibt:

  | Prüfpunkt | Ergebnis |
  |---|---|
  | Signing Authority | Apple Distribution: Sebastian Röber ✅ |
  | Provisioning Profile | iOS Team Store ✅ |
  | application-identifier App | XAGR3K7XDJ.de.roeber.LH2GPXWrapper ✅ |
  | application-identifier Widget | XAGR3K7XDJ.de.roeber.LH2GPXWrapper.Widget ✅ |
  | App Groups | group.de.roeber.LH2GPXWrapper (App + Widget) ✅ |
  | Entitlements | vollständig korrekt ✅ |
  | Run Script Build Phases | KEINE vorhanden ✅ |
  | `codesign --verify` | valid on disk ✅ |
  | `codesign --verify --strict` | does not satisfy its designated Requirement ❌ |

  **Bewiesene Ursache:** Designated Requirement enthält CN in Unicode NFD (`6f cc 88` = o + U+0308),
  tatsächliches Zertifikat hat CN in NFC (`c3 b6` = U+00F6 ö prekomponiert).
  Byte-Vergleich scheitert. Xcode Cloud / macOS Security Framework normalisiert CN zu NFD beim Einbetten der DR.
  Apple's Upload-Validator prüft mit `--strict` → "Code failed to satisfy specified code requirement(s)".

  **Ausgeschlossen:** Repo-Signing-Konfiguration, App ID, App Group, Profile, Entitlements — alle korrekt.

  **Fix (manuell, kein Repo-Eingriff nötig):**
  1. appleid.apple.com → persönliche Daten → Namen auf `Sebastian Roeber` ändern
  2. Xcode.app → Settings → Accounts → Distribution-Zertifikat revoken + neu erzeugen
  3. Xcode Cloud Clean Build starten
- Privacy Policy URL in App Store Connect eintragen: `https://dev-roeber.github.io/iOS-App/privacy.html` (Seite vorhanden, URL noch nicht eingetragen)
- Support URL in App Store Connect eintragen: `https://dev-roeber.github.io/iOS-App/support.html` (Seite vorhanden, URL noch nicht eingetragen)
- Marketing URL optional: `https://dev-roeber.github.io/iOS-App/` (`docs/index.html` vorhanden, kein Download-Button)
- finales App Icon (aktuell Interimsdesign)
- Apple-Review-Bestaetigung fuer NSPrivacyCollectedDataTypes (optionaler Live-Upload)
- iPad-Screenshots sind fuer v1 nicht relevant, solange `TARGETED_DEVICE_FAMILY = 1` bleibt; iPad-Support spaeter mit eigenem Test-/Screenshot-Set
- App-Store-Screenshots in App Store Connect hochladen (`docs/app-store-assets/screenshots/iphone-67/`)
- Apple-validen TestFlight-Build abwarten bzw. erzeugen; lokale Transporter-Uploads vom 2026-04-29 wurden mit `Invalid Signature` fuer App + Widget abgelehnt

---

## Statusstand 2026-04-13 — Apple-Developer-Basis + Xcode Cloud Setup

### Verifikation 2026-04-13

#### ✅ real eingerichtet / verifiziert (2026-04-13)

- **UITests Bundle ID bereinigt**: `xagr3k7xdj.de.roeber.lh2gpxwrapper.uitests` → `de.roeber.LH2GPXWrapper.UITests` (beide Konfigurationen Debug + Release in `project.pbxproj`) — Commit `d50dac3`
- **Bundle IDs konsistent**: Main `de.roeber.LH2GPXWrapper`, Widget `de.roeber.LH2GPXWrapper.Widget`, Tests `de.roeber.LH2GPXWrapperTests`, UITests `de.roeber.LH2GPXWrapper.UITests`
- **`.xcode-version`**: `26.3` in `wrapper/` — Xcode Cloud Version gepinnt
- **`ci_scripts/`**: erstellt unter `wrapper/ci_scripts/`, alle 3 Scripts ausführbar mit korrekten Xcode-Cloud-Namen: `ci_post_clone.sh`, `ci_pre_xcodebuild.sh` (Build-Nummern-Injektion), `ci_post_xcodebuild.sh` — Commit `d50dac3` + Korrektur `ci_pre_build.sh→ci_pre_xcodebuild.sh`
- **Xcode Cloud Runbook**: erstellt unter `docs/XCODE_CLOUD_RUNBOOK.md` (inkl. Hinweis auf gültige Skriptnamen)
- **Xcode Cloud Kompatibilität geprüft**: lokale SPM-Abhängigkeit (`relativePath = ".."`) ist Xcode-Cloud-kompatibel; `PBXFileSystemSynchronizedRootGroup` schließt `PrivacyInfo.xcprivacy` automatisch ein (kein expliziter pbxproj-Eintrag nötig)
- **Falsche Deployment-Target-Doku behoben**: `TESTFLIGHT_RUNBOOK.md` sagte `iOS 26.2` statt korrekter `16.0 / 16.2`
- **Veraltete Repo-Pfade bereinigt**: 7 Vorkommen von `~/repos/LocationHistory2GPX-Monorepo` in 4 Dateien → `~/Desktop/XCODE/iOS-App`
- **swift test**: 616 Tests, 0 Failures — `xcodebuild generic/platform=iOS`: BUILD SUCCEEDED

#### ⚠️ manuelle Apple-Schritte (blocking für Xcode Cloud Start)

1. **Historischer Stand 2026-04-13:** Xcode Cloud Workflow war damals noch manuell anzulegen; Stand 2026-04-29 ist `Release – Archive & TestFlight` inzwischen erstellt
2. **App ID registrieren**: `de.roeber.LH2GPXWrapper` + Capabilities: App Groups, Background Modes (Location)
3. **App Group registrieren**: `group.de.roeber.LH2GPXWrapper` im Developer Portal
4. → Details: `docs/XCODE_CLOUD_RUNBOOK.md`

## Statusstand 2026-04-12 — Device Smoke-Test + Widget Privacy Manifest

### Verifikation 2026-04-12

Ausgefuehrt auf: macOS, Xcode 26.3, iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C)

#### ✅ real verifiziert (2026-04-12)

- **Device Smoke-Test**: App `de.roeber.LH2GPXWrapper` auf iPhone 15 Pro Max installiert, gestartet, PID 29955 stabil — kein Crash
- **Widget Privacy Manifest**: `wrapper/LH2GPXWidget/PrivacyInfo.xcprivacy` erstellt und im `.xcodeproj` verankert (UUID 176C3AD213714BC7AC963476); UserDefaults CA92.1 deklariert, `NSPrivacyTracking: false`
- **ZIPFoundation 0.9.20 Privacy Manifest**: vorhanden (FileTimestamp 0A2A.1) — kein eigener Handlungsbedarf
- **Signing** (Team XAGR3K7XDJ, Automatic): funktioniert fuer Device-Build
- **Store-Archive-Pfad**: `wrapper/LH2GPXWrapper.xcodeproj` (Wrapper-Scheme), nicht SPM-Scheme
- `swift test` (macOS): 606 Tests, 0 Failures, 0 Skips (Stand 2026-04-12 nach Build-Fix-Batch mit 6 gepatchten Dateien)

## Statusstand 2026-04-02 — Apple-Device-Verifikation nach Performance-Fix

### Mac + Xcode + iPhone Verifikation (2026-04-02)

Ausgefuehrt auf: macOS, Xcode 26.3, iPhone 15 Pro Max (iOS 26.3), iPhone Air (iOS 26.3.1)

#### ✅ real verifiziert (2026-04-02)

- `xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build`: BUILD SUCCEEDED
- `xcodebuild -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`: BUILD SUCCEEDED
- `xcodebuild archive -scheme LH2GPXWrapper -destination 'generic/platform=iOS'`: ARCHIVE SUCCEEDED (TestFlight-Archiv lokal erzeugbar; Upload erfordert App Store Connect)
- `swift test`: 586 Tests, 0 Failures (Stand 2026-04-12)
- `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`: BUILD SUCCEEDED inkl. eingebettetem Widget (Stand 2026-04-12)
- `make deploy` im Wrapper: Build, Install und Launch auf `iPhone_15_Pro_Max` und `iPhone_12_Pro_Max` erfolgreich (Stand 2026-04-12)
- PrivacyInfo.xcprivacy vorhanden und technisch konsistent mit aktuellem App-Verhalten (UserDefaults CA92.1 deklariert, `NSPrivacyCollectedDataTypePreciseLocation` fuer optionalen Live-Upload eingetragen, `NSPrivacyTracking: false`)
- Device-Launch auf iPhone 15 Pro Max: `testLaunch` gruен
- Device-Smoke-Test `testDeviceSmokeNavigationAndActions` auf iPhone 15 Pro Max: PASSED (44s)
  - Load Demo Data: App startet sauber, Demo-Daten laden ohne Crash
  - Overview → Heatmap-Sheet: oeffnet real, schliesst sauber
  - Insights → Share-Button: Share-Sheet erscheint real (ImageRenderer-Pfad ausgeloest)
  - Export-Tab → Export-Action-Button: fileExporter wird real ausgeloest (koordinatenbasierter Tap selektiert Tag, export.action.primary ist enabled und loest System-Datei-Sheet aus)
  - Live-Tab → Start/Stop Recording: Location-Permission-Prompt erscheint, Recording startet und stoppt sauber
- Wrapper-Auto-Restore mit deterministischem Launch-Reset via `LH2GPX_UI_TESTING` + `LH2GPX_RESET_PERSISTENCE` verifiziert
- Signing/Bundle Identifier/Provisioning: ohne Fehler fuer Device-Build und Archiv
- **Background-Recording auf echtem iPhone: auf realem Gerät verifiziert (2026-04-02)** — Permission-Upgrade auf Always, Aufnahme im Hintergrund, Stop/Persistenz auf echtem Device geprüft und bestätigt
- **Upload-End-to-End zum eigenen HTTPS-Server auf echtem Gerät: per realem Device-Test bestätigt (2026-04-02)** — optionaler nutzergesteuerter Upload an eigenen Server auf echtem iPhone erfolgreich durchgelaufen

#### ⚠️ technisch offen (nicht moeglich ohne manuelle Session oder Apple-Account)

- TestFlight-Upload und Beta-Verifikation: Archiv existiert lokal, Upload erfordert App Store Connect-Zugang
- Finaler App Store Review: nicht lokal simulierbar

#### ❌ offen (Apple-Review / Store-Policy)

- Apple-Review-Bestaetigung fuer die bereits eingetragene `NSPrivacyCollectedDataTypePreciseLocation`-Deklaration des optionalen Live-Uploads steht weiter aus
- Datenschutzrichtlinien-URL fuer App Store Connect (Pflichtfeld, noch nicht eingetragen)
- Support-URL fuer App Store Connect (noch nicht eingetragen)

## Statusstand 2026-04-01

### Repo-Verifikation (Linux-only, ohne Apple-Hardware)

Dieser Audit-Block basiert ausschließlich auf Quellcode- und Dokumentationsanalyse auf dem Linux-Host. `xcodebuild` ist hier nicht verfügbar.

#### ✅ repo-verifiziert (Stand 2026-04-01)

- Info.plist im Wrapper enthält `NSLocationWhenInUseUsageDescription` mit App-Store-tauglichem Text
- Info.plist im Wrapper enthält `NSLocationAlwaysAndWhenInUseUsageDescription` mit App-Store-tauglichem Text
- `UIBackgroundModes=location` ist in Info.plist deklariert
- PrivacyInfo.xcprivacy ist unter `wrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy` vorhanden
- PrivacyInfo.xcprivacy erklärt `NSPrivacyTracking: false` und leere `NSPrivacyTrackingDomains`
- PrivacyInfo.xcprivacy erklärt `NSPrivacyAccessedAPITypes: [UserDefaults CA92.1]`
- Server-Upload ist standardmäßig deaktiviert (`isEnabled: false` in `LiveLocationServerUploadConfiguration`)
- Server-Upload erfordert explizite Nutzerkonfiguration: URL muss eingetragen werden
- HTTPS wird für nicht-localhost-Endpunkte im Code erzwungen (`endpointURL`-Getter)
- Bearer-Token wird im Keychain gespeichert, nicht in UserDefaults
- `defaultTestEndpointURLString = ""` — kein hart kodierter Testendpunkt im Code
- Nur akzeptierte Live-Recording-Punkte (Lat/Lon/Timestamp/Accuracy) werden übertragen
- Keine Analytics, kein Ad-Tracking, kein Cloud-Sync für importierte History
- `swift test`: 586 Tests, 0 Failures (2026-04-12; dieser Alt-Block wurde nachgezogen)

#### ⚠️ benötigt Apple-Hardware/Xcode

- Frischer `xcodebuild archive` und `xcodebuild test` für den aktuellen konsolidierten Repo-Stand
- Verifikation, ob `NSPrivacyCollectedDataTypes` in PrivacyInfo.xcprivacy für den optionalen Server-Upload ergänzt werden muss (Apple Review-Entscheidung)
- Verifikation ob ZIPFoundation-Abhängigkeit eigene Privacy-Manifest-Anforderungen mitbringt (file-timestamp-Zugriffe)
- Live-Location-Permission-Flow auf echtem Gerät oder Simulator (WhenInUse → AlwaysAllow)
- Heatmap-Sheet öffnen und visuell/performanceseitig verifizieren
- Neuer `Live`-Tab mit Status-Chips, Quick Actions und Upload-Zuständen funktional durchbedienen
- Neue `Insights`-Segmente auf echtem Gerät auf Lesbarkeit prüfen
- Wrapper-Auto-Restore kontrolliert verifizieren (Positiv-, Datei-fehlt-, Clear-Pfad)

#### ❌ offen (Apple-Review / Store-Policy)

- Apple-seitige Scope-/Review-Einordnung für den optionalen Server-Upload: Apple entscheidet, ob das Datentypen-Deklaration in `NSPrivacyCollectedDataTypes` erfordert
- Datenschutzrichtlinien-URL für App Store Connect (Pflichtfeld, noch nicht eingetragen)
- Support-URL für App Store Connect (noch nicht eingetragen)
- TestFlight-Upload und Beta-Verifikation (erfordert App Store Connect-Zugang)
- Finaler App Store Review (kann nicht lokal simuliert werden)

## Statusstand 2026-03-31

### Wichtige Einschraenkung

Der Verifikationsstand vom 2026-03-17 basiert auf einem aelteren Repo-Stand (vor den 2026-03-18/19/20-Commits). Die seither hinzugekommenen Features (Live-Tab, Heatmap, Background-Recording, Server-Upload) sind auf Apple-Hardware nicht separat verifiziert.

Der frische Host-Nachweis dieses Audits ist Linux-only: `swift test` lief am 2026-03-31 mit `228` Tests, `2` Skips und `0` Failures. `xcodebuild` ist auf diesem Linux-Host nicht verfuegbar; aus diesem Audit stammen deshalb keine neuen Apple-CLI- oder Device-Claims.

Die Apple-CLI-/Device-Nachweise vom 2026-03-30 bleiben als historische Nachweise dokumentiert. Diese Gruen-Aussagen gelten nur fuer die damals protokollierten CLI-Builds/-Tests; sie ersetzen weiterhin keine frische Device-End-to-End-Verifikation der spaeter hinzugekommenen Features.

Apple Device Verification Batch 1 (2026-03-30) hat zusaetzlich einen echten iPhone-Teilbefund geliefert:

- verbundenes Geraet: `iPhone 15 Pro Max` (`iPhone16,2`), iOS `26.3 (23D127)`, via USB verfuegbar und entsperrt
- `xcodebuild test -allowProvisioningUpdates -project /Users/sebastian/Code/LH2GPXWrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'id=00008130-00163D0A0461401C' -only-testing:LH2GPXWrapperUITests` lief gegen dieses Geraet real an
- `LH2GPXWrapperUITestsLaunchTests.testLaunch` lief auf dem echten iPhone erfolgreich durch
- `LH2GPXWrapperUITests.testAppStoreScreenshots` scheiterte nicht an Launch oder Signing, sondern daran, dass der erwartete `Demo Data`-Button im realen Startzustand nicht vorhanden war
- der zugehoerige Accessibility-Snapshot zeigte einen bereits wiederhergestellten Import (`Imported file: location-history.zip`) im Uebersichtsbildschirm sowie sichtbare Einstiege fuer `Heatmap` und den dedizierten `Live`-Tab
- daraus folgt: Device-Launch, sichtbarer Auto-Restore und die grundsaetzliche Praesenz von `Heatmap`/`Live` sind jetzt teilbelegt; Oeffnen und funktionales Durchlaufen dieser Pfade bleibt offen

Heatmap UX Batch 1 (2026-03-30) hat danach nur Display-/Bedienungsdetails des Heatmap-Sheets veraendert:

- lokale Controls fuer Deckkraft, Radius-Presets, `Auf Daten zoomen` und eine kleine Dichte-Legende
- ruhigere Darstellung auf mittleren/grossen Zoomstufen sowie kompaktere Sheet-Chrome
- fuer diese UX-Aenderungen existiert in diesem Batch bewusst kein neuer Apple-Device-Nachweis; der Heatmap-Device-Status bleibt deshalb offen

Heatmap Visual & Performance Batch 2 (2026-03-30) hat den Renderer danach strukturell umgestellt:

- geglaettete aggregierte Polygon-Zellen statt sichtbar ueberlappender Einzelkreis-Stempel
- viewport-basierte Zellselektion mit per-LOD begrenzten sichtbaren Elementen
- wiederverwendbarer Viewport-Cache fuer ruhigere Zoom-/Pan-Reaktionen
- zwei kleine Heatmap-Regressionstests fuer Aggregation und viewport-/limit-respektierende Sichtbarkeit
- fuer diese Rendering-/Performance-Aenderungen existiert in diesem Batch bewusst ebenfalls kein neuer Apple-Device-Nachweis; der Heatmap-Device-Status bleibt offen

Heatmap Color / Contrast / Opacity Batch 3 (2026-03-30) hat danach nur die visuelle Schicht des neuen Renderers nachgeschaerft:

- staerkeres nichtlineares Deckkraft-Mapping, damit 100 % im Slider sichtbar voller wirkt
- weich interpolierte Farbpalette statt grober Farbstufen
- angehobene Intensitaetskurve fuer besser sichtbare mittlere/hohe Dichte
- drei kleine Logiktests fuer Intensitaets-Lift, High-End-Opacity und waermer werdende Palette
- auch fuer diese Farb-/Kontrast-Aenderungen existiert in diesem Batch bewusst kein neuer Apple-Device-Nachweis; der Heatmap-Device-Status bleibt offen

Der spaetere Live-/Upload-/Insights-/Days-Batch vom 2026-03-30 hat zusaetzlich produktnahe UI-/State-Aenderungen gebracht:

- `Days` sortiert jetzt standardmaessig `neu -> alt`
- der dedizierte `Live`-Tab wurde mit neuer Kartenhierarchie, Status-Chips, Quick Actions und mehr Live-Metriken deutlich ausgebaut
- der optionale Server-Upload zeigt jetzt Queue-, Failure- und Last-Success-Zustaende sowie Pause/Resume und manuellen Flush
- die Insights-Seite bietet jetzt segmentierte Oberflaechen (`Overview`, `Patterns`, `Breakdowns`) mit KPI-Karten, Highlight-Karten, `Top Days` und Monatstrends
- fuer diesen Batch liegen auf dem Linux-Server nur gezielte `swift test --filter Live|Insight|Day|Upload`-Laeufe vor; ein neuer Apple-Device-Nachweis existiert dafuer bewusst noch nicht

### Bereits real verifiziert (2026-03-17, vor Post-2026-03-18-Features)

- [x] Xcode-Schemes aus dem Swift Package sind ueber das echte Xcode sichtbar
- [x] `LocationHistoryConsumerApp` baut fuer `platform=macOS` (2026-03-17; nach Apple Stabilization Batch 1: macOS-Build-Fehler behoben, Wrapper-iOS-Build gruen)
- [x] das gebaute App-Shell-Binary startet sichtbar in einer echten foreground-App-Session
- [x] `Load Demo Data`
- [x] `Open location history file`
- [x] `Open Another File` ersetzt bestehenden Inhalt
- [x] `Clear` / Reset
- [x] invalides JSON mit erhaltenem letztem gueltigen Inhalt
- [x] echter Zero-Day-Export / no days
- [x] Day-Liste und Day-Detail als echter UI-Durchgang

### Seit Phase 13 zusaetzlich verifiziert

- [x] reproduzierbarer foreground-Launch via `scripts/run_app_shell_macos.sh` (standardisiertes .app-Bundle statt ad-hoc-Wrapper)

### Historischer Apple-CLI-Stand (2026-03-30)

- [x] `swift build --target LocationHistoryConsumerAppSupport` laeuft fehlerfrei auf macOS
- [x] `swift build` (alle Targets) laeuft fehlerfrei auf macOS
- [x] `swift test` lief auf macOS durch: 224 Tests, 0 Failures
- [x] `xcodebuild test -scheme LocationHistoryConsumer-Package -destination 'platform=macOS'` lief auf macOS durch: 224 Tests, 0 Failures
- [x] `xcodebuild build -scheme LH2GPXWrapper -destination generic/platform=iOS` erfolgreich
- [x] `xcodebuild -list` (Wrapper Package Resolution) erfolgreich
- [x] `xcodebuild test -project /Users/sebastian/Code/LH2GPXWrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -only-testing:LH2GPXWrapperTests` erfolgreich
- [x] manueller Xcode-Start auf dem verbundenen iPhone liegt als separater positiver Teilbefund vor; er ersetzt keine CLI-Aussage
- [x] Wrapper-Launch auf echtem iPhone 15 Pro Max via XCUITest-Runner erneut belegt (`LH2GPXWrapperUITestsLaunchTests.testLaunch`)

### Noch offen

- [ ] frischen Apple-CLI-Gegenlauf fuer den aktuellen konsolidierten Repo-Stand auf einem Apple-Host nachziehen; auf diesem Linux-Host nicht moeglich
- [ ] foreground-Run explizit ueber `Product > Run` in Xcode selbst noch einmal separat bestaetigen, falls genau dieser IDE-spezifische Laufweg regressionskritisch wird
- [ ] Live-Location-/Permission-Flow inklusive optionaler `Always Allow`-Erweiterung fuer Background-Recording in einer echten Apple-UI-Session verifizieren und separat protokollieren; dabei den seit 2026-04-12 gegateten Startpfad (`awaitingAlwaysUpgrade` -> `recording`) explizit mitpruefen
- [ ] den dedizierten `Live`-Tab auf iPhone/iOS 17+ funktional verifizieren; Sichtbarkeit im realen AX-Snapshot ist belegt, echte Interaktion noch nicht
- [ ] das Heatmap-Sheet fuer importierte History auf Apple-Hardware visuell und performanceseitig verifizieren; der Einstieg ist im realen AX-Snapshot sichtbar, das Sheet selbst noch nicht geoefnet, und die spaeter hinzugekommenen UX-Controls, der neue Aggregations-/Polygon-Renderer sowie das Batch-3-Farb-/Kontrast-Mapping sind auf Device ebenfalls noch nicht separat bestaetigt
- [ ] die neue `Days`-Default-Sortierung (`neu -> alt`) in compact und regular auf Apple-Hardware funktional bestaetigen
- [ ] den deutlich ausgebauten `Live`-Tab auf Apple-Hardware funktional bestaetigen, inklusive Status-Chips, Quick Actions und erweitertem Stat-Set
- [ ] die neue segmentierte Insights-Oberflaeche (`Overview`, `Patterns`, `Breakdowns`) auf Apple-Hardware auf Lesbarkeit und Navigation pruefen
- [x] **Background-Recording auf echtem iPhone verifiziert (2026-04-02)** — Permission-Upgrade auf Always, Aufnahme im Hintergrund, Stop/Persistenz: auf realem Gerät bestätigt
- [x] **Upload-End-to-End zum eigenen Server auf echtem iPhone verifiziert (2026-04-02)** — optionaler nutzergesteuerter HTTPS-Upload: per realem Device-Test bestätigt
- [ ] Wrapper-Auto-Restore nach Reaktivierung (2026-03-20) kontrolliert mit Positiv-, Datei-fehlt- und Clear-Pfad auf echtem Device nachweisen; ein spontaner positiver Restore-Befund liegt jetzt vor

## Reale Apple-UI-Session 2026-03-17

- Host: macOS 15.7 (`24G222`)
- Xcode: 26.3 (`Build version 17C529`)
- `xcode-select -p`: `/Applications/Xcode.app/Contents/Developer`
- Swift unter echtem Xcode: `Apple Swift version 6.2.4`
- Apple-CLI-Schritte wurden weiterhin explizit mit `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` gefahren
- fuer die echte interaktive UI-Verifikation wurde das gebaute SwiftPM-App-Binary als foreground-App gestartet; seit Phase 13 ist dieser Schritt ueber `scripts/run_app_shell_macos.sh` standardisiert (baut, wrapped in minimales .app-Bundle, startet per `open`)
- diese Session predatiert spaetere 2026-03-20-Features wie Heatmap-Sheet, dedizierten `Live`-Tab und Upload-Batching; dafuer existiert hier absichtlich noch kein Apple-Haken
- verifizierte UI-Dateien:
  - Demo: gebuendelte `golden_app_export_sample_small.json`
  - gueltiger Import: lokale Kopie von `Fixtures/contract/golden_app_export_sample_small.json`
  - invalid: lokale Datei `lh2gpx_invalid.json` mit kaputter JSON
  - no-days: `Fixtures/contract/golden_app_export_no_days_zero.json` bzw. lokale Kopie davon fuer den nativen Dateiimporter

## Konkrete Pruefschritte

### 1. Build in Xcode

- Schritt:
  - `LocationHistoryConsumerApp` waehlen
  - `My Mac` waehlen
  - `Product > Build`
- Erfolg gilt als:
  - Build endet ohne Fehler
  - kein zusaetzliches Xcode-Projekt oder Feature-Scope ist noetig
- Status 2026-03-17:
  - verifiziert

### 2. App-Start

- Schritt:
  - foreground-App starten
- Erfolg gilt als:
  - App startet in den import-first Leerlaufzustand
  - kein sofortiger Crash
- Status 2026-03-17:
  - verifiziert
  - sichtbarer Startscreen mit `Import your location history` real bestaetigt
  - kein Crash
  - Hinweis: der spezifische IDE-Lauf `Product > Run` wurde in dieser Phase nicht noch einmal separat als foreground-Nachweis festgehalten

### 3. Open location history file

- Schritt:
  - `Open location history file` klicken
  - z. B. `Fixtures/contract/golden_app_export_sample_small.json` waehlen
- Erfolg gilt als:
  - Status `Location history loaded` oder `Google Timeline loaded`
  - Quelle `Imported file: <dateiname>.json`
  - Overview, Day-Liste und Day-Detail sichtbar
- Status 2026-03-17:
  - verifiziert
  - echte lokale Datei ueber den nativen Apple-Dateiimporter geoeffnet
  - aktive Quelle zeigte `Imported file: lh2gpx_valid_small.json`
  - Overview, Day-Liste und Day-Detail waren sichtbar

### 4. Demo laden

- Schritt:
  - `Load Demo Data` klicken
- Erfolg gilt als:
  - Status `Demo data loaded`
  - Quelle `Demo fixture: golden_app_export_sample_small.json`
  - zwei Demo-Tage sichtbar
- Status 2026-03-17:
  - verifiziert
  - aktive Quelle und Toolbar-Aktionen wechselten wie erwartet
  - Day-Liste zeigte real `2024-05-01` und `2024-05-02`

### 5. Clear / Reset

- Schritt:
  - nach geladenem Inhalt `Clear` klicken
- Erfolg gilt als:
  - Rueckfall auf `No location history loaded`
  - Quelle `None`
  - Startbuttons wieder sichtbar
- Status 2026-03-17:
  - verifiziert
  - Rueckfall auf `Import your location history` und `No location history loaded` real bestaetigt

### 6. Fehlerfall mit ungueltiger JSON

- Schritt:
  - lokale Datei mit kaputtem JSON importieren
- Erfolg gilt als:
  - Fehlerzustand `Unable to open file`, `Unsupported file format` oder `File could not be opened`
  - bei vorhandenem Inhalt bleibt letzter gueltiger Stand sichtbar
- Status 2026-03-17:
  - verifiziert
  - Fehlerkarte fuer den jeweiligen Importfehler erschien real
  - Meldung fuer den konkreten Decoder-/Formatfehler erschien real
  - letzter gueltiger importierter Inhalt blieb sichtbar

### 7. Leerer Export / no days

- Schritt:
  - no-days-geeignete Exportdatei laden
- Erfolg gilt als:
  - Overview bleibt sichtbar
  - Day-Liste zeigt `No Days Available`
  - Detailbereich bleibt im no-days-Zustand
- Status 2026-03-17:
  - verifiziert
  - echte Zero-Day-Fixture `golden_app_export_no_days_zero.json` verwendet
  - Day-Liste zeigte `No Days Available`
  - Detailbereich zeigte `No Day Details Available`
  - Statuskarte erklaerte, dass aktuell keine Day-Entries vorhanden sind

### 8. Darstellung Day-Liste / Day-Detail

- Schritt:
  - mit Demo oder importierter Datei durch die Liste navigieren
- Erfolg gilt als:
  - Day-Auswahl reagiert
  - Detailbereich zeigt Daten fuer den gewaehlten Tag
  - keine neue Business-Logik wird dafuer benoetigt
- Status 2026-03-17:
  - verifiziert
  - Demo- und Import-Zustand zeigten reale Day-Listen
  - Detailbereich fuer den initial selektierten Tag war real sichtbar
  - Fehler- und no-days-Zustaende liessen die Detailflaeche nachvollziehbar in sinnvolle Apple-UI-Leerzustaende wechseln
