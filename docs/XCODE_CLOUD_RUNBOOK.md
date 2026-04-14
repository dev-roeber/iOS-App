# Xcode Cloud Runbook

Stand: 2026-04-13

## Repo-Struktur (relevant für Xcode Cloud)

```
iOS-App/                        ← git root (dieses Repo)
├── Package.swift               ← Core Swift Package (lokale Abhängigkeit)
├── wrapper/
│   ├── LH2GPXWrapper.xcodeproj ← Xcode-Projekt (hier Xcode Cloud zeigen)
│   ├── .xcode-version          ← "26.3" — Xcode Cloud Versionspinning
│   └── ci_scripts/             ← Xcode Cloud Hooks
│       ├── ci_post_clone.sh      ← Post-Clone (derzeit No-op, dokumentiert)
│       ├── ci_pre_xcodebuild.sh  ← Build-Nummer aus CI_BUILD_NUMBER injizieren
│       └── ci_post_xcodebuild.sh ← Post-Build Status-Logging
```

Das `LH2GPXWrapper.xcodeproj` referenziert `Package.swift` über
`XCLocalSwiftPackageReference` mit `relativePath = ".."`.
Xcode Cloud löst diese lokale Abhängigkeit automatisch auf, da beide
im selben Repository liegen.

---

## Aktueller Signing-Stand

| Target              | Bundle ID                          | Team       | Signing   |
|---------------------|------------------------------------|------------|-----------|
| LH2GPXWrapper (App) | `de.roeber.LH2GPXWrapper`          | XAGR3K7XDJ | Automatic |
| LH2GPXWidget        | `de.roeber.LH2GPXWrapper.Widget`   | XAGR3K7XDJ | Automatic |
| LH2GPXWrapperTests  | `de.roeber.LH2GPXWrapperTests`     | XAGR3K7XDJ | Automatic |
| LH2GPXWrapperUITests| `de.roeber.LH2GPXWrapper.UITests`  | XAGR3K7XDJ | Automatic |

**App Groups:** `group.de.roeber.LH2GPXWrapper` (App + Widget, UserDefaults-Datenaustausch)

**Entitlements:**
- `wrapper/LH2GPXWrapper/LH2GPXWrapper.entitlements` — App
- `wrapper/LH2GPXWidget/LH2GPXWidget.entitlements` — Widget Extension

---

## Xcode Cloud Workflow einrichten (manuelle GUI-Schritte)

Xcode Cloud Workflows können ausschließlich in Xcode.app oder
App Store Connect konfiguriert werden — keine YAML-Dateien.

### Voraussetzung
- Apple Developer Account mit Team XAGR3K7XDJ ist aktiv
- App ID `de.roeber.LH2GPXWrapper` in Developer Portal registriert
- App Group `group.de.roeber.LH2GPXWrapper` im Developer Portal registriert

### Workflow in Xcode einrichten (einmalig)

1. **Xcode öffnen:** `wrapper/LH2GPXWrapper.xcodeproj`
2. **Menü:** Product → Xcode Cloud → Create Workflow
3. **Einstellungen des ersten Workflows:**
   - **Name:** `CI – Build & Test`
   - **Start Condition:** Branch Changes → `main`
   - **Environment:** Xcode 26.3, macOS 15 (latest)
   - **Actions:**
     1. **Build** — Scheme: `LH2GPXWrapper`, Platform: iOS Simulator
     2. **Test** — Scheme: `LH2GPXWrapper`, Plan: `LH2GPXWrapper.xctestplan`
        - Ziele: `LH2GPXWrapperTests` (parallelisiert), `LH2GPXWrapperUITests`
   - **Post-Actions:** (optional) TestFlight Distribution → erst wenn stabile
     Release-Candidate-Builds angestrebt werden
4. **Save & Start** → Erster Cloud-Build startet

### Zweiter Workflow: Archive & TestFlight (wenn bereit)

1. **Menü:** Product → Xcode Cloud → Create Workflow
2. **Name:** `Release – Archive & TestFlight`
3. **Start Condition:** Tag starts with `v` (z.B. `v1.0.0`)
4. **Actions:**
   1. **Archive** — Scheme: `LH2GPXWrapper`, Platform: iOS
   2. **TestFlight (Internal Testing)** — automatisch nach Archive
5. **Save**

### Wichtig: App Store Connect Pflichtfelder (vor erstem Upload)

Vor dem ersten TestFlight-Upload müssen in App Store Connect gesetzt sein:
- **Privacy Policy URL** (extern gehostete Datenschutzerklärung)
- **Support URL**
- **App-Beschreibung** (DE + EN)
- **Screenshots** (iPhone 6.7" Pflicht, iPad optional)

---

## Build-Nummern-Logik

`ci_pre_xcodebuild.sh` injiziert `CI_BUILD_NUMBER` (Xcode Cloud Auto-Variable)
in `CFBundleVersion` beider Info.plist-Dateien (App + Widget).
`MARKETING_VERSION` (1.0) bleibt unberührt — nur die Build-Nummer wird
automatisch hochgezählt.

**Wichtig:** Xcode Cloud erkennt nur diese exakten Skriptnamen:
- `ci_post_clone.sh`
- `ci_pre_xcodebuild.sh`
- `ci_post_xcodebuild.sh`

Andere Namen (z.B. `ci_pre_build.sh`) werden stillschweigend ignoriert.

App Store Connect erfordert eindeutige `(version, build)`-Tupel.

---

## Lokaler Build-Nachweis (Referenz)

```bash
# Wrapper-Build + Tests auf Simulator
xcodebuild test \
  -project wrapper/LH2GPXWrapper.xcodeproj \
  -scheme LH2GPXWrapper \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 17'

# Auf echtem Gerät deployen (Makefile)
cd wrapper && make deploy
```

---

## Bekannte Xcode Cloud Kompatibilitätspunkte

| Punkt | Status |
|-------|--------|
| Lokale SPM-Abhängigkeit (`relativePath = ".."`) | Xcode Cloud-kompatibel, da im selben Repo |
| ZIPFoundation (Fork `dev-roeber/ZIPFoundation`, Tag `0.9.20-devroeber.1`) | Xcode Cloud-kompatibel; nur Zugriff auf `dev-roeber/ZIPFoundation` erforderlich |
| `ci_scripts/` vorhanden und ausführbar | ✅ |
| `.xcode-version` gesetzt (26.3) | ✅ |
| Scheme `LH2GPXWrapper` ist shared | ✅ |
| App Groups Entitlement im Developer Portal | Manuell einzurichten (einmalig) |
| Privacy Manifest (`PrivacyInfo.xcprivacy`) | ✅ vorhanden (App + Widget) |

---

## ZIPFoundation Fork-Abhängigkeit

**Stand:** 2026-04-14 (gehärtet von branch auf exact-Tag)

ZIPFoundation wird seit 2026-04-14 über den eigenen Fork `dev-roeber/ZIPFoundation` bezogen.
Seit dem Härte-Schritt (ebenfalls 2026-04-14) ist die Dependency auf einen unveränderlichen
Tag gepinnt statt auf einen Branch — für reproduzierbare CI/Xcode-Cloud-Builds.

| Attribut | Wert |
|---|---|
| Fork-URL | `https://github.com/dev-roeber/ZIPFoundation.git` |
| SPM-Strategie | `.exact("0.9.20-devroeber.1")` |
| Tag | `0.9.20-devroeber.1` |
| Revision (gepinnt) | `d6e0da4509c22274b2775b0e8c741518194acba1` |
| Basis | ZIPFoundation 0.9.20 (upstream) + "Update copyright year"-Commit |
| Früherer Upstream | `https://github.com/weichsel/ZIPFoundation.git` (entfernt) |
| Frühere Strategie | `branch: "development"` (nicht reproduzierbar) → ersetzt |

**Warum `.exact()` statt Branch:**
- Branch-Pins sind nicht reproduzierbar: jeder neue Commit auf `development` ändert den Build
- Xcode Cloud und andere CI-Systeme erwarten stabile, prüfbare Dependency-Hashes
- `.exact()` garantiert, dass immer dieselbe Revision gezogen wird

**Warum `.exact()` statt `.upToNextMinor()`:**
- `0.9.20-devroeber.1` ist ein Pre-Release-Identifier — SPM würde ihn bei Range-Auflösung
  übergehen; `.exact()` ist die einzige zuverlässige Methode für Pre-Release-Tags

**Upgrade-Prozess (wenn Fork aktualisiert wird):**
```bash
# 1. Fork-Update einspielen
cd /tmp && git clone https://github.com/dev-roeber/ZIPFoundation.git
cd ZIPFoundation
git remote add upstream https://github.com/weichsel/ZIPFoundation.git
git fetch upstream && git merge upstream/main
git push origin development

# 2. Neuen Tag setzen
git tag -a "0.9.20-devroeber.2" HEAD -m "Release 0.9.20-devroeber.2"
git push origin "0.9.20-devroeber.2"

# 3. Im iOS-App Repo
# Package.swift: exact: "0.9.20-devroeber.2"
swift package resolve
# Commit: Package.swift + Package.resolved
```

---

## Offene manuelle Apple-Schritte (Blocking für Xcode Cloud Start)

1. **Xcode Cloud in Xcode.app aktivieren** (einmalig): Product → Xcode Cloud → Create Workflow
   → Apple ID Login + Team XAGR3K7XDJ auswählen → Repository verbinden
2. **App ID registrieren** (falls noch nicht geschehen):
   Developer Portal → Identifiers → `de.roeber.LH2GPXWrapper` + Capabilities: App Groups, Background Modes (Location)
3. **App Group registrieren:** `group.de.roeber.LH2GPXWrapper`
4. **Ersten Workflow speichern und Build starten**

Nach diesen 4 Schritten läuft Xcode Cloud vollautomatisch bei jedem Push auf `main`.
