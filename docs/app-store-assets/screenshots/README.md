# App Store Screenshots – LH2GPX

## Status (Stand 2026-05-01)

| Set | Erstellt | Build-Stand | ASC-Status |
|-----|----------|-------------|------------|
| `iphone-67/` 01–06 | 2026-04-29 (iPhone 15 Pro Max) | Build 44 (vor Redesign) | in ASC seit Build 71 |
| `iphone-67/` 07–08 | **ausstehend** | Build 73 (nach Redesign) | nicht in ASC |

**Handlungsbedarf:** Alle 6 vorhandenen Screenshots zeigen das alte UI-Layout (vor dem LH2GPX-Dark-Redesign). Für Build 73 müssen alle 8 Slots neu aufgenommen werden.

---

## Sicherheitsregeln

- **Keine echten Standortdaten** — ausschließlich Repo-Demo-Fixture (`app_export_sample.json`)
- **Keine privaten Orte** (kein Wohnort, kein Arbeitsort, keine Adresse)
- **Keine Server-URL** sichtbar (Upload standardmäßig deaktiviert, kein Endpunkt voreingestellt)
- **Kein Bearer Token** sichtbar (SecureField, nie im Klartext)
- **Keine E-Mail, Telefonnummer, Debug-Overlays**
- **Keine GPS-Rohdaten** direkt sichtbar
- Dark Mode (LH2GPX-Dark-Designsystem)

---

## Erzeugungsverfahren

### Automatisiert (bevorzugt) — UITest `testAppStoreScreenshots`

```bash
# Auf iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C) oder iPhone 17 Pro Max Simulator
xcodebuild test \
  -project wrapper/LH2GPXWrapper.xcodeproj \
  -scheme LH2GPXWrapper \
  -destination 'id=00008130-00163D0A0461401C' \
  -only-testing:LH2GPXWrapperUITests/LH2GPXWrapperUITests/testAppStoreScreenshots

# Screenshots aus xcresult extrahieren
xcrun xcresulttool export \
  --path <result.xcresult> \
  --output-path /tmp/ss-build73 \
  --type directory
# → PNGs nach docs/app-store-assets/screenshots/iphone-67/ kopieren

# Skalierung für 6.5-inch-Slot (falls benötigt)
sips --resampleWidth 1242 --cropToHeightWidth 2688 1242 iphone-67/*.png \
  --out iphone-65/
```

Ablauf intern:
1. `LH2GPX_UI_TESTING` + `LH2GPX_RESET_PERSISTENCE` — sauberer Startzustand
2. Demo-Daten laden (`app_export_sample.json`), `range.chip.all` aktivieren
3. 8 Screenshots als `XCTAttachment` im xcresult-Bundle gespeichert

### Manuell (Fallback)

1. Xcode öffnen → `LH2GPXWrapper` Scheme → iPhone 15 Pro Max (echt oder Simulator: iPhone 17 Pro Max)
2. Dark Mode: Einstellungen → Darstellung → Dunkel
3. Sprache: Englisch oder Deutsch je nach Zielmarkt
4. Demo-Daten laden: `Load Demo Data` antippen
5. Jeden Screen einzeln aufrufen und mit `Cmd+S` / Seitentaste + Lautstärke aufnehmen
6. Screens in Reihenfolge (s. Tabelle unten)

---

## Slot-Übersicht für App Store Connect (Build 73)

| Slot | Datei | Screen | Inhalt |
|------|-------|--------|--------|
| 1 | `01-import.png` | Start / Import | Leer-Zustand, Import-Buttons sichtbar |
| 2 | `02-overview-map.png` | Übersicht mit Karte | Demo-Daten, All-Time-Filter, Track-Overlays |
| 3 | `03-days.png` | Tage-Liste | Gefilterte Tagesliste mit Demo-Einträgen |
| 4 | `04-insights.png` | Insights Dashboard | KPI-Karten, Aktivitätsübersicht |
| 5 | `05-export.png` | Export Checkout | Redesignter Stepper, Format-Pills, Sticky-Bar |
| 6 | `06-live-recording.png` | Live Tracking | Dark Layout, Mint-Polyline, Status-Chips |
| 7 | `07-options.png` | Optionen | 8-Section-NavigationLink-Grid, Dark Cards |
| 8 | `08-day-detail.png` | Tagesdetail | Map-first, Route-Ansicht mit Demo-Tag |

---

## Ordner

### `iphone-67/` — 1290×2796 px

Nativer iPhone 15 Pro Max Screenshot (3× Retina, 6.7-inch Display).
→ **Für App Store Connect: diesen Slot bevorzugt verwenden** ("6.7-inch Display").

Aktueller Stand: Dateien 01–06 vorhanden (Build 44, altes Layout). **Müssen für Build 73 neu aufgenommen werden.**

### `iphone-65/` — 1242×2688 px

Proportional skaliert aus `iphone-67/` für den App Store Connect "6.5-inch"-Slot.

---

## iPad

`TARGETED_DEVICE_FAMILY = 1` (iPhone-only v1). iPad-Screenshots sind für v1 nicht erforderlich.

## Apple Watch

Keine WatchKit-App im Repo vorhanden. Keine Watch-Screenshots nötig.
