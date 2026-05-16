# Lokaler iPhone-Betrieb – Runbook

Stand: 2026-03-30

---

## Ziel

Die App lokal auf echten iPhones und im Simulator reproduzierbar starten, testen und verifizieren.
Dieses Runbook ersetzt keine App-Store-Einreichung – es dient dem lokalen Entwicklungs- und Verifikationsbetrieb.

iPad-Betrieb kommt spaeter. Dieser Schritt fokussiert iPhone.

---

## Simulator-Betrieb

### Verfuegbare Simulatoren (Stand 2026-03-17, Xcode iOS 26.x)

iOS 26.x bietet folgende iPhone-Simulatoren:

| Simulator | Verfuegbar |
|-----------|-----------|
| iPhone 17 Pro Max | ja (UDID: F671FA96-892A-4849-AD86-3EE9FF8FEB36) |
| iPhone 17 Pro | ja |
| iPhone 17 | ja |
| iPhone 17e | ja |
| iPhone Air | ja |
| iPhone 16e | ja |
| **iPhone 15 Pro Max** | **nein** (kein iOS-26-Simulatorziel) |
| **iPhone 12 Pro Max** | **nein** (kein iOS-26-Simulatorziel) |

**Hinweis:** Apple stellt fuer iOS 26.x keine Simulatorziele fuer aeltere Modelle bereit.
Verifizierung auf iPhone 12 Pro Max und iPhone 15 Pro Max ist nur auf echtem Geraet moeglich.

### Simulator starten (CLI)

```bash
cd ~/Desktop/Github-ios/LH2GPXWrapper

# Build + Launch im Simulator
xcodebuild -project LH2GPXWrapper.xcodeproj \
  -scheme LH2GPXWrapper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' \
  build

# Alternativ: kleinstes verfuegbares Geraet (iPhone 16e)
xcodebuild -project LH2GPXWrapper.xcodeproj \
  -scheme LH2GPXWrapper \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' \
  build
```

### Verfuegbare Simulatoren pruefen

```bash
xcrun simctl list devices available | grep -E "iOS 26" -A 30 | grep iPhone
```

### Unit-Tests im Simulator

```bash
xcodebuild test \
  -project LH2GPXWrapper.xcodeproj \
  -scheme LH2GPXWrapper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' \
  -only-testing:LH2GPXWrapperTests
```

---

## Simulator-Verifikationsstatus (2026-03-30)

| Flow | Status | Geraet |
|------|--------|--------|
| Build (`xcodebuild build`) | verifiziert | generic/platform=iOS |
| Unit-Tests | verifiziert (`xcodebuild test -only-testing:LH2GPXWrapperTests` gruen) | iPhone 17 Pro Max, iOS 26.3.1 |
| Demo-Daten | verifiziert (Screenshots 02-04) | iPhone 17 Pro Max, iOS 26.3.1 |
| Import-State | verifiziert (Screenshot 01) | iPhone 17 Pro Max, iOS 26.3.1 |
| Day-Liste | verifiziert | iPhone 17 Pro Max, iOS 26.3.1 |
| Day-Detail + Karte | verifiziert | iPhone 17 Pro Max, iOS 26.3.1 |
| Persistenz / Restore | Wrapper-Auto-Restore ist im Code aktiv; frische Simulator-Verifikation offen | n/a |

---

## Geraete-Deploy (echtes iPhone)

### Voraussetzungen

- Xcode mit aktivem Development-Signing (Team XAGR3K7XDJ)
- iPhone per USB verbunden, Geraet vertraut gesetzt
- Deployment Target: iOS 26.2 – das Geraet muss mindestens iOS 26.2 laufen

### Deploy per Xcode (empfohlen)

1. `LH2GPXWrapper.xcodeproj` in Xcode oeffnen
2. Scheme `LH2GPXWrapper` waehlen
3. Zielgeraet (iPhone 15 Pro Max oder iPhone 12 Pro Max) auswaehlen
4. Product > Run

### Deploy per CLI

```bash
cd ~/Desktop/Github-ios/LH2GPXWrapper

xcodebuild -project LH2GPXWrapper.xcodeproj \
  -scheme LH2GPXWrapper \
  -destination 'platform=iOS,name=<Geraetename>' \
  build
```

### Geraet-UDIDs pruefen

```bash
xcrun xctrace list devices 2>/dev/null | grep -v "Simulator"
```

---

## Geraete-Verifikationsstatus (Stand 2026-03-30)

| Geraet | iOS-Version | Deploy | Demo | Import (app_export.json) | Import (location-history.json) | Persistenz | Karte |
|--------|-------------|--------|------|--------------------------|-------------------------------|-----------|-------|
| iPhone 17 Pro Max | 26.3 (Simulator) | ✅ (Build) | ✅ | ✅ | Codepfad unterstuetzt, frische End-to-End-Verifikation offen | Codepfad aktiv, frische Verifikation offen | ✅ |
| iPhone 15 Pro Max | iOS 26.2 | ✅ Deploy | ✅ Demo | ✅ | frische Verifikation offen | Codepfad aktiv, frische Verifikation offen | ✅ |
| iPhone 12 Pro Max | iOS 26.2 | ✅ Deploy | ✅ Demo | ✅ | frische Verifikation offen | Codepfad aktiv, frische Verifikation offen | ✅ |

**Aktueller Befund (2026-03-30):**
- fuer diesen Batch liegt zusaetzlich ein positiver manueller Xcode-Start auf dem verbundenen iPhone vor; dieser Befund ist bewusst getrennt von den CLI-Build-/Test-Ergebnissen zu lesen
- App laeuft weiterhin auf iPhone 15 Pro Max und iPhone 12 Pro Max fuer die bereits verifizierten Import-/Kartenflows
- Google-Takeout-`location-history.json` / `.zip` wird im aktuellen Code direkt unterstuetzt
- der Wrapper ruft `restoreBookmarkedFile()` beim Start wieder auf; fuer diese Reaktivierung liegt in diesem Batch kein frischer Device-Nachweis vor
- Live-Location / Live-Recording ist implementiert; optionales Background-Recording ist im aktuellen Code vorbereitet, aber ein separat protokollierter iPhone- oder Simulator-UI-Durchlauf fuer diesen erweiterten Flow steht noch aus
- die Optionen-Seite bietet jetzt auch Deutsch/Englisch und optionalen Server-Upload fuer akzeptierte Live-Recording-Punkte
- eine frische End-to-End-Geraeteverifikation fuer den konfigurierbaren Server-Upload steht noch aus

**Apple Device Verification Batch 1 (2026-03-30, echtes iPhone):**
- Geraet: `iPhone 15 Pro Max` (`iPhone16,2`), iOS `26.3 (23D127)`, per USB verbunden, entsperrt, Developer Mode aktiv
- `xcodebuild test -allowProvisioningUpdates -project /Users/sebastian/Code/LH2GPXWrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'id=00008130-00163D0A0461401C' -only-testing:LH2GPXWrapperUITests` lief real gegen dieses Geraet
- `LH2GPXWrapperUITestsLaunchTests.testLaunch` lief auf dem echten iPhone erfolgreich durch
- `LH2GPXWrapperUITests.testAppStoreScreenshots` scheiterte inhaltlich: statt leerem Import-State war bereits ein wiederhergestellter Import aktiv, daher fehlte der erwartete `Demo Data`-Button
- der zugehoerige Accessibility-Snapshot zeigte:
  - Uebersicht mit `Imported file: location-history.zip`
  - sichtbare `Heatmap`-Aktion bei geladenem Import
  - sichtbaren dedizierten `Live`-Tab in der Tab-Bar
- daraus folgt:
  - Launch auf echter Hardware: **verifiziert**
  - Wrapper-Auto-Restore: **teilweise verifiziert** (positiver spontaner Restore-Befund)
  - `Heatmap` und `Live`: **teilweise verifiziert** (sichtbar/verdrahtet, aber nicht funktional durchbedient)
  - Background-Recording und Upload: **offen**

**Unterstuetztes Import-Format:**
- ✅ `app_export.json` – erzeugt von [LocationHistory2GPX](https://github.com/dev-roeber/LocationHistory2GPX) Python-Tool
- ✅ `location-history.json` / `.zip` – Google Takeout Timeline Export, wird direkt konvertiert

**Aktuell dokumentierter Verifikationsstand:**
- [x] Build + Install per Xcode
- [x] App starten → Import-Zustand sichtbar
- [x] Demo-Daten laden → Day-Liste sichtbar
- [x] Ersten Eintrag tippen → Day-Detail + Karte
- [ ] location-history.json / .zip auf aktuellem Stand separat erneut auf echtem Geraet pruefen
- [x] Import-State anzeigen → leerer Zustand sauber
- [ ] App schliessen, neu starten → Wrapper-Auto-Restore nach der 2026-03-20-Reaktivierung kontrolliert mit Positiv-, Datei-fehlt- und Clear-Pfad auf echtem Geraet verifizieren
- [ ] Live-Location-Permission, aktueller Standort, Live-Track-Aufnahme und optionale `Always Allow`-Erweiterung fuer Background-Recording separat auf echtem Geraet oder Simulator protokollieren
- [ ] optionalen Server-Upload mit echtem Endpunkt auf aktuellem Geraet separat pruefen

Befunde in dieses Runbook als Tabelle nachtragen.

---

## Persistenz / Restore – Testplan (manuell auf Geraet)

> **Repo-Truth 2026-03-30:** Die Core-App-Shell haelt Auto-Restore weiter geparkt. Der Wrapper hat `restoreBookmarkedFile()` am 2026-03-20 wieder aktiviert. Der Testplan unten gilt deshalb fuer den aktuellen Wrapper-Code und braucht eine frische Device-Verifikation.

### Code-Review-Status (2026-03-30)

Die Restore-Logik ist im Wrapper aktiv im Code sichtbar. In Apple Device Verification Batch 1 liegt jetzt ein echter positiver Teilbefund vom iPhone 15 Pro Max vor: beim Device-Launch war bereits eine wiederhergestellte `location-history.zip` aktiv. Ein kontrollierter Positiv-/Fallback-/Clear-Durchlauf steht trotzdem weiter aus.

**Implementierung:** `ImportBookmarkStore` + `restoreBookmarkedFile()` in ContentView.
- iOS-Bookmarks ohne Security-Scope (korrekt fuer iOS)
- Stale-Bookmark wird automatisch erneuert
- Bei Fehler: Bookmark wird gecleant, Fehlermeldung erscheint
- `showFailure()` setzt `isLoading = false` korrekt

### Manueller Restore-Testplan

Auf **jedem Geraet** folgenden Flow pruefen und Ergebnis nachtragen:

**Positiver Pfad:**
1. `app_export.json` importieren → Day-Liste erscheint
2. App vollstaendig schliessen (aus App-Switcher entfernen)
3. App neu starten
4. Erwartet: Datei wird automatisch wiederhergestellt, Day-Liste erscheint ohne erneuten Import

**Fehler-/Fallback-Pfad:**
5. Datei aus Files.app loeschen oder verschieben
6. App neu starten
7. Erwartet: Fehlermeldung "Unable to restore previous import", kein Absturz, Import-Zustand sauber

**Clear-Pfad:**
8. Clear-Button tippen
9. App schliessen und neu starten
10. Erwartet: Import-Zustand, kein Restore, keine alte Datei

### Befunde (offen)

| Geraet | Positiver Restore | Datei-fehlt-Fallback | Clear-nach-Restore |
|--------|------------------|---------------------|-------------------|
| iPhone 15 Pro Max | teilweise verifiziert – Device-Launch 2026-03-30 zeigte bereits wiederhergestellte `location-history.zip`; kontrollierter Positiv-Pfad weiter offen | offen – noch kein kontrollierter Datei-fehlt-Durchlauf auf aktuellem Stand | offen – noch kein kontrollierter Clear-nach-Restore-Durchlauf auf aktuellem Stand |
| iPhone 12 Pro Max | offen – historischer Nachweis 2026-03-17, aber vor der Reaktivierung 2026-03-20 | offen – historischer Nachweis 2026-03-17, aber vor der Reaktivierung 2026-03-20 | offen – historischer Nachweis 2026-03-17, aber vor der Reaktivierung 2026-03-20 |

---

## iPad

iPad-Betrieb kommt bewusst spaeter.
Screenshots fuer ASC sind bereits erstellt (`docs/appstore-screenshots/ipad/`).
Produktiver iPad-Run-Fokus: nachgelagert nach iPhone-Verifikation.

---

## Zusammenhang mit anderen Dokumenten

| Dokument | Inhalt |
|----------|--------|
| `docs/TESTFLIGHT_RUNBOOK.md` | App Store Connect / TestFlight (bewusst geparkt bis ASC-Zugang) |
| `docs/appstore-screenshots/` | Screenshots fuer ASC (lokal erstellt, 2026-03-17) |
| Core-Repo `docs/XCODE_RUNBOOK.md` | Xcode-Runbook fuer das Swift Package |
| Core-Repo `docs/APPLE_VERIFICATION_CHECKLIST.md` | Verifikations-Gates |
