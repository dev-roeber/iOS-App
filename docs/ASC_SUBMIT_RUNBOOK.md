# App Store Connect — Submit-Runbook (Build 74 / Guideline 3.2 Response)

Stand: 2026-05-05

---

## Aktueller ASC-Status (Stand: 2026-05-05)

| Punkt | Wert |
|-------|------|
| Version | 1.0 |
| Status | **`Abgelehnt`** |
| Ablehnungsdatum | 2026-05-01 |
| Abgelehnter Build | **74** |
| Ablehnungsgrund | Guideline 3.2 — Business / Other Business Model Issues |
| Submission ID | `1d2cc080-13cd-45cd-b3e0-c0259a75ce5c` |
| Xcode Cloud aktuellster Build | **74** |
| Screenshots in ASC | Aus Build 71 (altes UI-Layout) |
| Repo HEAD | `ff4c413` — chore: Build 73 screenshot + submit prep |
| Lokale Build-Nummer (project.pbxproj) | 45 (von Xcode Cloud überschrieben via `ci_pre_xcodebuild.sh`) |

---

## Wichtig: Build-Nummer-Mapping

Xcode Cloud injiziert `CI_BUILD_NUMBER` automatisch in `CFBundleVersion` via `wrapper/ci_scripts/ci_pre_xcodebuild.sh`.
Die lokale `CURRENT_PROJECT_VERSION = 45` in `project.pbxproj` ist nur der Basis-Fallback für lokale Builds.
→ **Build 73 in Xcode Cloud** entspricht `CFBundleVersion = 73`, `MARKETING_VERSION = 1.0`.

---

## Aktuell blockierender Schritt: Guideline 3.2 Response

Vor einem erneuten Submit muss zuerst die Ablehnung adressiert werden:

1. **App Store Connect → Meine Apps → LH2GPX → Version 1.0 → Ergebnis anzeigen / Reply**
2. Review-Response aus `docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md` einfügen
3. Klarstellen: öffentliche Consumer-App, kein Account/Org-Binding, optionaler Upload = self-hosted, default OFF
4. Submit der Response abwarten

Erst nach positivem Outcome (oder neuem Feedback) ist ein weiteres Submit sinnvoll.

---

## Ziel des nächsten Submits (nach positivem Review-Response)

Neuester verfügbarer Build + neue Screenshots für das redesignte UI einreichen.

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

Version 1.0 ist aktuell im Status `Warten auf Prüfung`.
Screenshots und Build **können nicht direkt bearbeitet werden**, solange die Version in der Review-Queue ist.

### Ablauf

1. **App Store Connect öffnen**: https://appstoreconnect.apple.com → Meine Apps → LH2GPX → Version 1.0

2. **Aus Prüfung entfernen**:
   - Oben im gelben Hinweis-Banner auf `Diese Version aus der Prüfung entfernen` klicken
   - Alternativ: Schaltfläche `Remove from Review` oben rechts
   - Warten, bis Status wieder auf `Bereit zur Einreichung` / `Ready to Submit` wechselt

3. **Build ersetzen**:
   - Unter `Build` → aktuellen Build 71 entfernen (❌)
   - `Build hinzufügen` → Build 73 auswählen (muss in TestFlight verfügbar sein)
   - Falls Build 73 nicht erscheint: in Xcode Cloud prüfen, ob Upload abgeschlossen; ggf. einige Minuten warten

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
