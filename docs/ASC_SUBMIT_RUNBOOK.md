# App Store Connect — Submit-Runbook

Stand: 2026-05-05 | **Status: Ausstehende Entwicklerfreigabe (Pending Developer Release)**

---

## Aktueller ASC-Status (Stand: 2026-05-05)

| Punkt | Wert |
|-------|------|
| Version | 1.0 |
| **Status** | **`Ausstehende Entwicklerfreigabe (Pending Developer Release)`** |
| Guideline 3.2 | **Resolved / Accepted** — kein offener Ablehnungsgrund |
| Accepted-Datum | 2026-05-05 |
| Ablehnung (historisch) | 2026-05-01, Build 74, Guideline 3.2 |
| Submission ID | `1d2cc080-13cd-45cd-b3e0-c0259a75ce5c` |
| Xcode Cloud aktuellster Build | **74** |
| Screenshots in ASC | Aus Build 71 (altes UI-Layout) — vor neuem Submit ersetzen |
| Repo HEAD | `3057cfc` — fix: clarify optional self-hosted upload (consumer UI clarification) |
| Lokale Build-Nummer (project.pbxproj) | 45 (von Xcode Cloud überschrieben via `ci_pre_xcodebuild.sh`) |
| **App live im Store** | **Nein** — bewusst nicht veröffentlicht |

---

## Wichtig: Build-Nummer-Mapping

Xcode Cloud injiziert `CI_BUILD_NUMBER` automatisch in `CFBundleVersion` via `wrapper/ci_scripts/ci_pre_xcodebuild.sh`.
Die lokale `CURRENT_PROJECT_VERSION = 45` in `project.pbxproj` ist nur der Basis-Fallback für lokale Builds.
→ **Build 74 in Xcode Cloud** entspricht `CFBundleVersion = 74`, `MARKETING_VERSION = 1.0`.

---

## Aktueller Plan: Neuen Build einreichen (Build 74 NICHT veröffentlichen)

Build 74 wurde akzeptiert, soll aber **nicht** als finale Version veröffentlicht werden.
Weiterentwicklung läuft; vor öffentlichem Release wird ein neuerer Build eingereicht.

### Schritt 1 — Weiterentwicklung + neuer Xcode-Cloud-Build

1. Neue Features/Fixes auf main entwickeln, testen, pushen
2. Xcode Cloud Workflow `Release – Archive & TestFlight` manuell starten
3. Neuer Build (≥ 75) erscheint automatisch in ASC/TestFlight

### Schritt 2 — Developer Reject (Version aus Release-Prozess entfernen)

1. App Store Connect → Meine Apps → LH2GPX → Version 1.0
2. Schaltfläche **„Developer Reject"** / **„Ablehnen"** klicken
3. Status wechselt auf `Bereit zur Einreichung` / `Ready to Submit`
4. Jetzt können Build, Screenshots und Metadaten bearbeitet werden

### Schritt 3 — Neuen Build + Screenshots einreichen

→ Weiter wie im Abschnitt „Manuelle ASC-Schritte" unten

---

## Ziel des nächsten Submits

Neuester Xcode-Cloud-Build + neue Screenshots (8 Slots, aktuelles Redesign) + ggf. Consumer-UI-Clarification-Stand (ab Build 75+).

---

## Voraussetzung: Screenshot-Neuerstellung

Vor dem Einreichen müssen neue Screenshots aufgenommen werden, da die aktuellen Bilder das alte UI zeigen.

### Schritt 1 — UITest ausführen (bevorzugt)

```bash
cd /Users/sebastian/iOS-App

xcodebuild test \
  -project wrapper/LH2GPXWrapper.xcodeproj \
  -scheme LH2GPXWrapper \
  -destination 'id=00008130-00163D0A0461401C' \
  -only-testing:LH2GPXWrapperUITests/LH2GPXWrapperUITests/testAppStoreScreenshots
```

→ Ergebnis: xcresult-Bundle mit 8 Anhängen (01-import bis 08-day-detail)

### Schritt 2 — Screenshots extrahieren

```bash
# Pfad zum xcresult herausfinden:
find ~/Library/Developer/Xcode/DerivedData -name "*.xcresult" -newer /tmp -maxdepth 6 | head -5

# Exportieren:
xcrun xcresulttool export \
  --path <PFAD_ZUM>.xcresult \
  --output-path /tmp/ss-build73 \
  --type directory

# Oder legacy:
xcrun xcresulttool get --legacy --path <PFAD>.xcresult --id <attachment-ref>
```

### Schritt 3 — Nach repo kopieren

```bash
cp /tmp/ss-build73/01-import.png docs/app-store-assets/screenshots/iphone-67/
# ... alle 8 Dateien
```

### Schritt 4 — Für 6.5-inch skalieren (optional)

```bash
for f in docs/app-store-assets/screenshots/iphone-67/*.png; do
  sips --resampleWidth 1242 "$f" --out "docs/app-store-assets/screenshots/iphone-65/$(basename $f)"
done
```

### Sicherheitscheck vor Upload

- [ ] Keine echten GPS-Koordinaten sichtbar (nur Demo-Fixture)
- [ ] Keine Server-URL im Upload-Screen sichtbar
- [ ] Kein Bearer Token sichtbar
- [ ] Keine privaten Orte (Wohnort, Arbeitsort) im Kartenausschnitt
- [ ] Keine Debug-Overlays oder Entwickler-Menüs
- [ ] Dark Mode aktiv, kein Light-Mode-Mischmasch

---

## Manuelle ASC-Schritte (von Sebastian auszuführen)

### Voraussetzung

Version 1.0 ist aktuell im Status `Ausstehende Entwicklerfreigabe (Pending Developer Release)`.
Für eine erneute Einreichung muss zuerst ein **Developer Reject** durchgeführt werden (s. Abschnitt oben).

### Ablauf

1. **App Store Connect öffnen**: https://appstoreconnect.apple.com → Meine Apps → LH2GPX → Version 1.0

2. **Developer Reject** (statt „Aus Prüfung entfernen"):
   - Schaltfläche `Developer Reject` / `Ablehnen` klicken
   - Warten, bis Status auf `Bereit zur Einreichung` / `Ready to Submit` wechselt
   - **Hinweis**: Dies entfernt Build 74 aus dem Release-Prozess; neuer Build muss gewählt werden

3. **Build ersetzen**:
   - Unter `Build` → aktuellen Build entfernen (❌)
   - `Build hinzufügen` → neuesten Xcode-Cloud-Build (≥ 75) auswählen
   - Falls neuer Build nicht erscheint: in Xcode Cloud prüfen, ob Upload abgeschlossen; ggf. einige Minuten warten

4. **Screenshots ersetzen**:
   - Unter `iPhone 6.7-inch Display` → alte Screenshots entfernen
   - 8 neue Screenshots hochladen: `01-import.png` bis `08-day-detail.png` aus `docs/app-store-assets/screenshots/iphone-67/`
   - Reihenfolge in ASC per Drag & Drop anpassen
   - `Speichern` klicken

5. **Erneut einreichen**:
   - `Zur Prüfung hinzufügen` / `Add for Review` klicken
   - `Einreichen` / `Submit for Review` bestätigen

6. **Nach dem Submit**:
   - Neuen ASC-Status dokumentieren (z. B. `Warten auf Prüfung` mit Build 73)
   - Sebastian teilt den neuen Status mit → Doku wird repo-wahr nachgezogen

---

## Risiken und Hinweise

| Risiko | Einschätzung |
|--------|-------------|
| Aus Prüfung entfernen startet Review-Queue neu | Ja — Wartezeit kann sich verlängern |
| Apple hat möglicherweise bereits Review begonnen | Falls `In Review` sichtbar: warten auf Apple-Entscheidung, nicht entfernen |
| Build 73 enthält das vollständige Redesign | Code-Stand: `34734ce` (main HEAD) — kein neuer Code nach truth sync |
| Hardware-Verifikation der neuen Redesign-Screens ausstehend | Live Activity / DI Lock Screen / minimal offen; Hauptpfade grün |
| Screenshots zeigen Simulator/Demo-Daten, nicht echte Nutzerdaten | Korrekt so — Policy-konform |
| Aus Prüfung entfernen ist irreversibel (ohne erneutes Submit) | Bestätigung in ASC erforderlich |

---

## Nicht von diesem Runbook abgedeckt

- TestFlight-Interne-Tester-Aktivierung (separat)
- Apple-Review-Feedback einarbeiten
- Neue Version (1.1) anlegen — erst nach positivem Review-Ergebnis relevant
