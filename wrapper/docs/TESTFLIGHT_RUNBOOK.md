# TestFlight + App Store Runbook

Stand: 2026-04-30 | Phase 20

---

## Lokal verifizierter Stand

| Punkt | Status | Nachweis |
|-------|--------|---------|
| `xcodebuild archive` | **verifiziert** | 2026-04-30, v1.0 Build 45, lokales Release-Archive erzeugbar |
| Bundle Identifier | `de.roeber.LH2GPXWrapper` | project.pbxproj |
| Marketing Version | `1.0` | project.pbxproj |
| Build Number | `45` | project.pbxproj |
| Display Name | `LH2GPX` | project.pbxproj |
| Deployment Target | iOS 16.0 (App, Tests); iOS 16.2 (Widget) | project.pbxproj |
| Signing | Automatic, Team `XAGR3K7XDJ`; lokaler Host signiert Archive derzeit mit `Apple Development`, Export zu ASC braucht zusaetzlich eine Distribution-Identitaet | project.pbxproj + lokaler Archive-Lauf 2026-04-30 |
| PrivacyInfo.xcprivacy | lokal sichtbar: kein Tracking, UserDefaults CA92.1, `PreciseLocation` fuer optionalen Live-Upload | PrivacyInfo.xcprivacy |
| App Icon | Map-Pin + "LH2GPX", 1024x1024 | Assets.xcassets/AppIcon.appiconset/ |
| App Review Guidelines | geprueft, mit offenem Wording fuer den optionalen Server-Upload | Abschnitt unten |

### Aktueller ASC-Stand

- App Store Connect: `LH2GPX` Version `1.0` ist eingereicht
- Status: `Warten auf Prüfung`
- Veröffentlichung: manuell
- auf der Versionsseite sichtbarer Build: `52`
- Xcode Cloud Workflow `Release – Archive & TestFlight`: erfolgreiche Builds `55`, `56`, `57`
- Review-Entscheidung: Build `52` bleibt bewusst in Review; kein Nachreichen eines neueren Builds ohne Apple-Feedback oder bestaetigten release-kritischen Fehler
- Review ist damit nicht mehr durch fehlenden Upload blockiert
- Live Activity / Dynamic Island bleibt fuer App-Review-Risiko trotzdem nur partiell hardware-verifiziert

---

## App Store Review Guidelines – Pruefergebnis

Geprueft gegen die relevanten Abschnitte (Stand 2026-03):

| Abschnitt | Befund | Status |
|-----------|--------|--------|
| 2.1 App Completeness | vollstaendiger Location-History-Viewer, Demo-Modus vorhanden | ✅ |
| 2.3.12 Placeholder Content | App Icon: Map-Pin + App-Name (kein Gradient-Placeholder mehr) | ✅ |
| 4.2 Minimum Functionality | NavigationSplitView, Day-Detail, Map, Import, Demo | ✅ |
| 5.1.1 Data Collection | standardmaessig lokal, kein Analytics-/Ad-Tracking; optionaler nutzerkonfigurierter HTTPS-Upload fuer akzeptierte Live-Recording-Punkte ist vorhanden; lokale Texte wurden darauf abgestimmt | teilweise |
| 5.1.2 Privacy Manifests | PrivacyInfo.xcprivacy vorhanden, UserDefaults CA92.1 und `PreciseLocation` fuer optionalen Upload eingetragen; offen bleibt nur die Apple-seitige Scope-/Review-Einordnung dieser Deklaration | teilweise |
| 5.1.5 Location | optionales lokales Live-Recording mit While-In-Use-Start und code-seitiger Background-Unterstuetzung nach `Always Allow`; kein ATT/Ad-Tracking | ✅ |

Aus dem lokalen Code- und Doku-Stand laesst sich kein finaler Review-Freigabeclaim ableiten. Offen bleiben die Apple-seitige Scope-/Review-Einordnung fuer den optionalen Server-Upload, frische Device-Verifikation des erweiterten Location-/Upload-Flows sowie alle Apple-Portal-/ASC-/Signing-Themen, die auf diesem Linux-Host nicht direkt verifizierbar sind.

---

## Trennung: lokal lösbar / extern / nachgelagert

### Lokal – erledigt

- [x] App Icon (kein Placeholder mehr, 2026-03-17)
- [x] `xcodebuild archive` verifiziert
- [x] Privacy / Compliance-Basis geprueft
- [x] App Review Guidelines geprueft

Noch offen innerhalb des lokalen Review-/Privacy-Blocks:
- [ ] Apple-seitige Scope-/Review-Einordnung fuer den optionalen Server-Upload belastbar nachziehen

### Lokal – erledigt (Screenshots)

- [x] Screenshots erstellt (2026-03-17, via UI-Test, docs/appstore-screenshots/)

### Extern – erfordern App Store Connect / Apple-Zugang

- [ ] App Store Connect Projekt anlegen (einmalig)
- [ ] App-Metadaten in ASC eintragen (Beschreibung, Keywords, Kategorie, URLs)
- [ ] Screenshots in ASC hochladen
- [ ] Distribution-Export signieren und hochladen
- [ ] TestFlight-Beta aktivieren (interne Tester)

### Nachgelagert – erst nach laufender Beta relevant

- [ ] Beta-Feedback einarbeiten
- [ ] ggf. Crash-Reports aus TestFlight pruefen

---

## Screenshots – lokaler Simulator-Workflow

### Erstellte Screenshots (2026-03-17)

Screenshots wurden via UI-Test (`LH2GPXWrapperUITests/testAppStoreScreenshots`) erzeugt
und liegen im Repo unter `docs/appstore-screenshots/`:

| Datei | Inhalt |
|-------|--------|
| `iphone/01_import_state.png` | Import / Leer-Zustand |
| `iphone/02_day_list.png` | Day-Liste nach Demo-Daten-Load |
| `iphone/03_day_detail.png` | Day-Detail mit Karte |
| `iphone/04_day_detail_stats.png` | Day-Detail gescrollt (Stats + Sections) |
| `ipad/01_import_state.png` | Import / Leer-Zustand |
| `ipad/02_day_list.png` | Day-Liste nach Demo-Daten-Load |
| `ipad/03_day_detail.png` | Day-Detail mit Karte |
| `ipad/04_day_detail_stats.png` | Day-Detail gescrollt (Stats + Sections) |

### Erforderliche Geräteklassen (App Store Connect)

| Klasse | Auflosung | Geraet (generisch) | Lokale UDID (Stand 2026-03-17, iOS 26.3.1) |
|--------|-----------|--------------------|--------------------------------------------|
| iPhone 6.9" | 1320 × 2868 | iPhone 17 Pro Max | `F671FA96-892A-4849-AD86-3EE9FF8FEB36` |
| iPad Pro 13" | 2752 × 2064 | iPad Pro 13-inch (M5) | `D381D195-1B2D-47C9-98E6-9C07F0C6A857` |

Mindestens 1 iPhone-Klasse ist Pflicht. Fuer den aktuellen v1-Stand sind keine iPad-Screenshots noetig,
weil der Release-Build auf `TARGETED_DEVICE_FAMILY = 1` (iPhone-only) steht.

**Hinweis zu UDIDs:** UDIDs sind maschinenspezifisch. Den passenden Simulator finden:
```bash
xcrun simctl list devices available "iOS 26.3" | grep "iPhone 17 Pro Max\|iPad Pro 13"
```

### Screenshots reproduzieren (UI-Test)

```bash
cd ~/Desktop/XCODE/iOS-App

# iPhone 17 Pro Max
# In LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift: deviceFolder = "iphone" (Standard)
xcodebuild test \
  -project wrapper/LH2GPXWrapper.xcodeproj \
  -scheme LH2GPXWrapper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' \
  -only-testing:LH2GPXWrapperUITests/LH2GPXWrapperUITests/testAppStoreScreenshots

# iPad Pro 13-inch
# In LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift: deviceFolder auf "ipad" aendern
xcodebuild test \
  -project wrapper/LH2GPXWrapper.xcodeproj \
  -scheme LH2GPXWrapper \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=latest' \
  -only-testing:LH2GPXWrapperUITests/LH2GPXWrapperUITests/testAppStoreScreenshots

# Output liegt in /tmp/lh2gpx_screenshots/{iphone,ipad}/
# Danach kopieren:
cp /tmp/lh2gpx_screenshots/iphone/*.png wrapper/docs/appstore-screenshots/iphone/
cp /tmp/lh2gpx_screenshots/ipad/*.png wrapper/docs/appstore-screenshots/ipad/
```

### Screenshot-Screens

1. `01_import_state` – Import-/Leer-Zustand beim App-Start
2. `02_day_list` – Day-Liste nach Demo-Daten-Load
3. `03_day_detail` – Day-Detail-Ansicht mit Karte und Pfad
4. `04_day_detail_stats` – Day-Detail gescrollt mit Stats und Sections

---

## Archive-Build (lokal reproduzierbar)

```bash
cd ~/Desktop/XCODE/iOS-App

xcodebuild archive \
  -project wrapper/LH2GPXWrapper.xcodeproj \
  -scheme LH2GPXWrapper \
  -destination 'generic/platform=iOS' \
  -archivePath ~/Desktop/LH2GPXWrapper.xcarchive
```

Verifiziert 2026-04-30: `** ARCHIVE SUCCEEDED **`, v1.0 Build 45.

---

## Distribution-Export (nach Archive)

ExportOptions.plist anlegen:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>XAGR3K7XDJ</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
</dict>
</plist>
```

```bash
xcodebuild -exportArchive \
  -archivePath ~/Desktop/LH2GPXWrapper.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath ~/Desktop/LH2GPXWrapper_export
```

Lokaler Host-Befund 2026-04-30 (verifiziert):
- `security find-identity -v -p codesigning`: **0 valid identities found** — kein Zertifikat (weder Apple Development noch iOS Distribution) im Keychain
- Provisioning Profiles (`~/Library/MobileDevice/Provisioning Profiles/`): **0 Profile installiert**
- `xcodebuild -exportArchive` scheitert mit: `Failed to load profile. Profile is missing the required UUID property.`
  - Root Cause: keine Provisioning Profiles + kein Distribution-Zertifikat im lokalen Keychain
- ASC-Authentifizierung: keine `AuthKey_*.p8`, kein App-spezifisches Passwort — Upload per CLI nicht moeglich
- damit ist ein lokaler Export/Upload auf diesem Host derzeit **nicht** moeglich

**Manuelle Schritte zum Freischalten des Export-Pfads:**

Option 1 – Xcode GUI (empfohlen):
1. Xcode oeffnen → Settings → Accounts → Apple ID `sebastian.roeber94@gmail.com` pruefen
2. Team `XAGR3K7XDJ` auswählen → Manage Certificates → Distribution-Zertifikat erstellen falls fehlend
3. `Product > Archive` ausfuehren (Build 45, v1.0)
4. Organizer oeffnen → Archive waehlen → Distribute App
5. App Store Connect → Upload → Automatically manage signing → Team XAGR3K7XDJ
6. Upload abschliessen → App Store Connect > TestFlight > Build 45 prüfen

Option 2 – Xcode Cloud (empfohlen falls GUI blockiert):
- Xcode Cloud Workflow `Release – Archive & TestFlight` ist bereits angelegt und einmalig gruen gelaufen (Build 44, 2026-04-29)
- In Xcode: Xcode Cloud → Workflows → Release-Workflow → Run manuell starten
- Build 45 wird nach erfolgreichem Xcode Cloud Build automatisch in ASC/TestFlight sichtbar

Alternativ: Xcode Organizer → Distribute App → App Store Connect → Upload.

---

## App Store Connect – manuelle Schritte (externer Zugang erforderlich)

### App anlegen (einmalig)
- appstoreconnect.apple.com → Apps → + Neue App
- Plattform: iOS
- Name: LH2GPX
- Bundle ID: `de.roeber.LH2GPXWrapper`
- SKU: z. B. `LH2GPX-001`

### Metadaten
- **Name:** LH2GPX
- **Untertitel** (optional, max. 30 Z.): Location History Viewer
- **Kurzbeschreibung** (max. 170 Z.):\
  Importiere deinen Google-Location-Verlauf und sieh ihn als Tageslisten mit Karte.
- **Beschreibung:**\
  LH2GPX laedt deinen exportierten Google-Location-Verlauf (app_export.json) und
  zeigt ihn als uebersichtliche Tagesliste mit Detail-Ansicht und Karte.
  Besuche, Aktivitaeten und Pfade werden strukturiert dargestellt.
  Die App arbeitet standardmaessig lokal und offline. Der optionale Server-Upload von
  Live-Standortpunkten ist ausschliesslich nutzergesteuert, erfordert aktive Konfiguration
  und ist standardmaessig deaktiviert.
- **Keywords:** location history, google takeout, karte, standortverlauf, gpx
- **Kategorie:** Dienstprogramme (Utilities)
- **Support-URL:** `https://dev-roeber.github.io/iOS-App/support.html` (eingetragen 2026-04-30) ✅
- **Datenschutzrichtlinien-URL:** `https://dev-roeber.github.io/iOS-App/privacy.html` (eingetragen 2026-04-30) ✅

### TestFlight aktivieren
- App Store Connect → TestFlight → Build waehlen
- Beta App Description: "Erster interner Beta-Build von LH2GPX"
- Interne Tester (Apple ID) hinzufuegen
- Build freigeben

CLI-Upload ist nur moeglich, wenn zusaetzlich mindestens einer dieser Pfade eingerichtet ist:
- JWT-Auth: `--api-key` + `--api-issuer` + zugehoerige `AuthKey_*.p8`
- Username/App-Passwort-Auth: `--username` + App-spezifisches Passwort + `--provider-public-id`

Lokaler Host-Befund 2026-04-30:
- `altool --list-providers` scheitert ohne konfigurierte Authentifizierung
- daher bleibt Upload/ASC-Aktivierung ab diesem Punkt manuell bzw. auf einem anders vorbereiteten Apple-Host noetig

---

## Fazit Readiness

Lokal ist alles vorbereitet, was ohne ASC-Zugang moeglich ist.
Die verbleibenden Schritte sind klar getrennt und dokumentiert.
Phase 21 (v1.0 Release) beginnt erst nach Beta-Abschluss und Feedback-Einarbeitung.
