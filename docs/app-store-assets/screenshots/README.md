# App Store Screenshots – LH2GPX

## Erzeugungsverfahren

Screenshots wurden am 2026-04-29 auf einem **iPhone 15 Pro Max** (UDID `00008130-00163D0A0461401C`, iOS 26.3) mittels des UITests `testAppStoreScreenshots` erzeugt.

Ablauf:
1. `xcodebuild test -only-testing:LH2GPXWrapperUITests/testAppStoreScreenshots` auf dem echten Gerät
2. Screenshots via `XCTAttachment` im xcresult-Bundle gespeichert
3. Extraktion: `xcrun xcresulttool get --legacy --path <result.xcresult> --id <ref>`
4. Skalierung für 6.5-inch-Slot: `sips --resampleWidth 1242 --cropToHeightWidth 2688 1242`

## Inhalt

- **Testdaten**: ausschließlich Repo-Demo-Fixture (`app_export_sample.json`), keine privaten Nutzerdaten
- **Keine Debug-Overlays**, keine Entwickler-Menüs, keine Tokens
- **Live-Tab**: zeigt optionalen/nutzerkonfigurierten Upload-Screen ohne feste Server-URL
- **Keine feste Entwickler-Server-URL** sichtbar

## Ordner

### `iphone-67/` — 1290×2796 px

Nativer iPhone 15 Pro Max Screenshot (3× Retina, 6.7-inch Display).
→ **Für App Store Connect: diesen Slot bevorzugt verwenden** ("6.7-inch Display").

| Datei | Screen |
|-------|--------|
| `01-import.png` | Import / Leer-Zustand vor erstem Import |
| `02-overview-map.png` | Übersicht mit Karte (All-Time, Demo-Daten) |
| `03-days.png` | Tage-Liste |
| `04-insights.png` | Einblicke / Statistiken |
| `05-export.png` | Export-Tab (GPX, KML, KMZ, GeoJSON, CSV) |
| `06-live-recording.png` | Live-Aufzeichnung (optional, nutzerkonfiguriert) |

### `iphone-65/` — 1242×2688 px

Proportional skaliert aus `iphone-67/` für den App Store Connect "6.5-inch"-Slot.

## iPad

`TARGETED_DEVICE_FAMILY = "1,2"` → iPad wird unterstützt.
iPad-Screenshots sind noch ausstehend (kein iPad-Gerät bei der Erstellung angeschlossen).

## Apple Watch

Keine WatchKit-App im Repo vorhanden. Keine Watch-Screenshots nötig.
