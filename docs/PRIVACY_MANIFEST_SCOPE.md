# Privacy Manifest Scope

Stand: 2026-04-30 | historischer Privacy-Scope-Snapshot, repo-wahr nachgezogen

> **Hinweis 2026-05-08 (Phase 9A — Wrapper/AppFlow-Wiring + Settings-Delete-Button + Landing-View)**: Phase 9A führt **keine neuen Datentypen, keine neuen Persistenz-Pfade und keine neuen Netzwerkaktivitäten** ein. Der neue Settings-Delete-Button "Delete imported local data" in `AppTechnicalOptionsView` ruft `LocalTimelineDeletionPresentation`/`LocalTimelineDeletionService` und ist **idempotent**: er löscht ausschließlich die lokale LocalTimelineStore-DB inkl. WAL/SHM + RenderCache + ImportStaging + ExportStaging unter `applicationSupportDirectory/LocationHistory2GPX/Imports/` bzw. den dokumentierten temporary-Roots. **Kein Live-Upload-Touch**, **kein Keychain-Touch**, **kein Bookmark-/Preferences-Cleanup** im Store-Pfad (es liegen keine Standortdaten in UserDefaults). Die Landing-View liest nur Session-Metadaten (Counts, Date Range, Source Filename), **kein `coord_blob`-Read**. Store-Pfad bleibt default AUS (`LH2GPX_LOCAL_TIMELINE_STORE`). **Keine Privacy-Doku-Konsequenz für public-facing privacy.html**; das Privacy-Doku-Update auf den tatsächlichen Rollout-Stand bleibt **Phase-9-Pflicht** vor produktivem Default-Rollout.

> **Hinweis 2026-05-08 (Phase 8B — Store-backed Heatmap LOD Cache + Heatmap-Doppelbug-Fix)**: Phase 8B führt **keine neuen Datentypen, keine neuen Persistenz-Pfade außer einer abgeleiteten Cache-Tabelle (`derived_cache`) lokal im selben Store, und keine neuen Netzwerkaktivitäten** ein. Die `derived_cache`-Tabelle ist eine rein lokale, additive Cache-Tabelle innerhalb der bereits in Phase 1..7B dokumentierten LocalTimelineStore-DB (unter `applicationSupportDirectory/LocationHistory2GPX/Imports/`, backup-excluded); sie hängt per FK + `ON DELETE CASCADE` am Import-Lifecycle und ist über `clearHeatmapCache(importID:)` invalidierbar. Cache-Payload trägt aggregierte Grid-Zellen, **keine Roh-Punkte** und keine personenbezogenen Identifikatoren. Schema bleibt `userVersion = 2` (rein additiv). **Keine Privacy-Doku-Konsequenz**; Store-Pfad bleibt default AUS und weiterhin Spike / pre-production. Heatmap-Doppelbug-Fix in `AppHeatmapModel.swift:55-77` ist Code-intern (zentralisierte Punkt-Sampling-Logik via `AppHeatmapPathSampler`) und ändert Datenflüsse nicht. Privacy-Doku-Update bleibt **Phase-9-Pflicht** vor produktivem Rollout.

> **Hinweis 2026-05-08 (Phase 8A — Store-backed Map Data Provider)**: Phase 8A führt **keine neuen Datentypen, keine neuen Persistenz-Pfade und keine neuen Netzwerkaktivitäten** ein — sie ergänzt nur einen Foundation-only Provider über den bereits in Phase 1..7B dokumentierten LocalTimelineStore (DB unter `applicationSupportDirectory/LocationHistory2GPX/Imports/`, backup-excluded) sowie zwei additive bbox-Indizes auf der bestehenden `paths`-Tabelle. **Keine Privacy-Doku-Konsequenz**; der Store-Pfad bleibt default AUS und ist weiterhin Spike / pre-production. Privacy-Doku-Update bleibt Phase-8B/9-Pflicht vor produktivem Rollout.

---

## 1. Datenpunkte: lokal / optional-Upload / automatisch / nutzergesteuert

| Funktion / Datum | lokal | optional-Upload | automatisch | nutzergesteuert |
|---|---|---|---|---|
| Importierte History lesen (app_export.json, ZIP, Google Timeline) | ✅ lokal | — | nein | ✅ ja (manueller Import) |
| Importierte History speichern (Security-Scoped Bookmark) | ✅ lokal (UserDefaults) | — | nach Import | ✅ ja (Clear löscht Bookmark) |
| Live-Standort anzeigen (Karte, aktueller Marker) | ✅ lokal | — | nur bei aktivem Recording | ✅ ja (Nutzer startet Recording) |
| Live-Track aufzeichnen (foreground) | ✅ lokal | — | nein | ✅ ja |
| Background-Recording | ✅ lokal | — | nach `Always Allow`-Permission | ✅ ja (explizite Option + Permission) |
| Saved Live Tracks persistieren | ✅ lokal (App Support Storage) | — | beim Stoppen der Aufnahme | ✅ ja |
| App-Preferences (Einheiten, Tab, Kartenstil, Sprache etc.) | ✅ lokal (UserDefaults) | — | bei Änderung | ✅ ja |
| Bearer-Token für Server-Upload | ✅ lokal (Keychain) | — | nein | ✅ ja |
| **Server-Upload akzeptierter Live-Punkte** | — | ✅ optional (HTTPS POST) | nein | ✅ ja (explizite Aktivierung + URL) |
| Export GPX / KML / GeoJSON | ✅ lokal (system fileExporter) | — | nein | ✅ ja |
| Analytics / Telemetrie / Ad-Tracking | ❌ nicht vorhanden | — | — | — |

### Payload des Server-Uploads (wenn aktiviert)

```json
{
  "source": "LocationHistory2GPX-iOS",
  "sessionID": "<UUID>",
  "captureMode": "foregroundWhileInUse | backgroundAlways",
  "sentAt": "<ISO8601>",
  "points": [
    {
      "latitude": 52.123,
      "longitude": 13.456,
      "timestamp": "<ISO8601>",
      "horizontalAccuracyM": 12.5
    }
  ]
}
```

Kein Name, kein Gerätename, keine Apple-ID, keine Unique-Device-ID im Payload.
Kein Upload von importierter History, Exports, Einstellungen oder anderen App-Daten.

---

## 2. Technischer Privacy-Stand (belastbare Aussagen, nicht juristisch)

### Info.plist (wrapper/Config/Info.plist)

| Key | Wert | Bewertung |
|---|---|---|
| `NSLocationWhenInUseUsageDescription` | „Your location is used only inside LH2GPX to show your position on the map and to record live tracks you start manually." | ✅ vorhanden, App-Store-tauglich |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | „Your location is used only inside LH2GPX to continue a live track you started manually, even when the app is no longer in the foreground." | ✅ vorhanden, App-Store-tauglich |
| `UIBackgroundModes` | `location` | ✅ korrekt für Background-Recording |
| `NSUserTrackingUsageDescription` | nicht vorhanden | ✅ korrekt, kein ATT/Ad-Tracking |
| `NSCalendarsUsageDescription` etc. | nicht vorhanden | ✅ korrekt, kein Kalender-/Kontakte-/Kamera-Zugriff |

### PrivacyInfo.xcprivacy (wrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy)

| Key | Wert | Bewertung |
|---|---|---|
| `NSPrivacyTracking` | `false` | ✅ korrekt, kein Cross-App-Tracking |
| `NSPrivacyTrackingDomains` | leer | ✅ korrekt |
| `NSPrivacyCollectedDataTypes` | `NSPrivacyCollectedDataTypePreciseLocation` fuer optionalen Live-Upload | ✅ technisch im Manifest abgebildet; Review-Auslegung bleibt Rest-Risiko |
| `NSPrivacyAccessedAPITypes` | UserDefaults CA92.1 | ✅ korrekt für Preferences-Speicherung |

### Upload-Sicherheit (Code-verifiziert)

- HTTPS für nicht-localhost erzwungen (`endpointURL`-Getter in `LiveLocationServerUploadConfiguration`)
- HTTP-Endpunkte für nicht-localhost-Adressen werden im Code explizit abgelehnt
- Bearer-Token im Keychain, nicht in UserDefaults
- Kein hart kodierter Testendpunkt: `defaultTestEndpointURLString = ""`
- Upload standardmäßig deaktiviert: `isEnabled: false` als Default
- Queue-Limit: 10.000 Punkte (älteste werden verworfen bei Overflow)

---

## 3. Apple-/Store-Review-Risiken

### 3a. NSPrivacyCollectedDataTypes für optionalen Server-Upload

**Stand 2026-04-12:** Das Manifest deklariert jetzt bereits `NSPrivacyCollectedDataTypePreciseLocation` fuer den optionalen, nutzerinitiierten Live-Upload.

**Technischer Stand:**
- Wenn Nutzer Upload aktiviert und URL konfiguriert, werden Lat/Lon/Timestamp/Accuracy an den Nutzer-eigenen Server gesendet
- Apple definiert `NSPrivacyCollectedDataTypePreciseLocation` als deklarierbaren Typ
- Ob eine optionale, nutzerinitiierte Funktion deklarationspflichtig ist, hängt von Apples konkreter Policy-Auslegung ab
- **Kann nur auf Apple-Hardware im Store-Review-Kontext final beantwortet werden**

**Aktuelle Manifest-Loesung:**
```xml
<key>NSPrivacyCollectedDataTypes</key>
<array>
  <dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypePreciseLocation</string>
    <key>NSPrivacyCollectedDataTypeLinked</key>
    <false/>
    <key>NSPrivacyCollectedDataTypeTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>
    <array>
      <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
    </array>
  </dict>
</array>
```
Diese Deklaration ist technisch mit dem aktuellen Code synchron; offen bleibt nur, ob Apple die Scope-Einordnung bei Review genauso akzeptiert.

### 3b. ZIPFoundation-Abhängigkeit

**Frage:** Bringt ZIPFoundation eigene Privacy-Manifest-Anforderungen mit (z.B. `NSPrivacyAccessedAPICategoryFileTimestamp`)?

**Stand:**
- ZIPFoundation 0.9.20 ist pinned in Package.resolved
- Viele ZIP-Bibliotheken lesen/schreiben Datei-Timestamps
- Ob ZIPFoundation ein eigenes Privacy Manifest mitbringt, ist auf diesem Linux-Host nicht verifizierbar
- **Prüfung auf Apple-Host:** `xcodebuild` generiert Warnings bei fehlenden Manifest-Deklarationen für bekannte SDK APIs

### 3c. Datenschutzrichtlinien-URL (Pflicht)

- App Store Connect verlangt eine Datenschutzrichtlinien-URL
- `https://dev-roeber.github.io/iOS-App/privacy.html` — in App Store Connect eingetragen (2026-04-30) ✅

### 3d. Support-URL

- App Store Connect Pflichtfeld
- `https://dev-roeber.github.io/iOS-App/support.html` — in App Store Connect eingetragen (2026-04-30) ✅

---

## 4. Nächste Schritte für Privacy Manifest auf Apple-Host

Stand 2026-04-02 — bereits erledigt:
- **`xcodebuild archive`**: ARCHIVE SUCCEEDED (2026-04-02, Xcode 26.3, iPhone 15 Pro Max)
- **Upload-End-to-End**: optionaler nutzergesteuerter HTTPS-Upload an eigenen Server auf echtem Gerät durchgelaufen und bestätigt (2026-04-02)
- **Background-Recording**: auf echtem iPhone verifiziert (2026-04-02)

Noch offen — erfordert Developer Account oder Apple-Store-Review:

1. **ZIPFoundation-Manifest prüfen:**
   Im generierten `.xcarchive` unter `Products/Applications/LH2GPX.app/Frameworks/` (falls als Framework eingebettet) oder direkt in der ZIPFoundation-Package-Quelle nach `PrivacyInfo.xcprivacy` suchen. `xcodebuild` zeigt Warnings bei fehlenden Manifest-Deklarationen.

2. **NSPrivacyCollectedDataTypes Entscheidung (bewusst verschoben — erfordert Developer Account):**
   - App Store Connect → App Privacy → „Data Types" — App Review prüfen ob Standortdaten-Deklaration angefragt wird
   - Alternativ: Apple Developer Forum / TSI (Technical Support Incident) für Policy-Klarstellung

3. **Privacy Nutrition Label in App Store Connect:**
   Basierend auf Ergebnis aus Punkt 2: Data Types für „Precise Location" ggf. mit „Optional, user-initiated, app functionality" deklarieren.

4. **PrivacyInfo.xcprivacy aktualisieren:**
   Falls Schritt 2 ergibt, dass Deklaration erforderlich: `NSPrivacyCollectedDataTypes` ergänzen (Template in Abschnitt 3a).

---

## 4b. LocalTimelineStore (Phase 1..7B)

Stand 2026-05-08: **Phase 1..7B abgeschlossen, Spike/pre-production, nicht UI-aktiv.** Dieser Abschnitt dokumentiert den Privacy-Engineering-Stand der Storage-Surface; **keine Apple-Freigabe-Aussage**, **kein Rollout**. Phase 7A ergänzt den feature-flagged AppContentLoader-Hook über die Envelope-Kapsel `AppSessionContentSource`; Phase 7B ergänzt eine Foundation-only Presentation/ViewState-Schicht (inkl. `LocalTimelineDeletionPresentation`) und einen Service-layer Envelope-Hook im AppFlow (`LH2GPXAppFlow.loadImportedFileEnvelope(...)`). Store-Pfad ist NIE default-aktiv, Default-Rollout bleibt Legacy-AppExport. **Kein Wrapper/SwiftUI-Wiring** — der produktive Settings-Button „Importierte Daten löschen" bleibt **Phase 8**.

- **Lokal-only.** Der LocalTimelineStore liegt ausschließlich auf dem Gerät. DB-Verzeichnis: `applicationSupportDirectory/LocationHistory2GPX/Imports/` (Datei `store.sqlite` + `-wal`/`-shm`); RenderCache unter `cachesDirectory/LocationHistory2GPX/RenderCache/`; ImportStaging und ExportStaging unter `temporaryDirectory/LocationHistory2GPX/`. Keine Drittweitergabe, kein Serverabgleich.
- **Keine Standortdaten in `UserDefaults`.** Bestätigt durch die Phase-4-Architektur: Geometrie/Timeline-Inhalte ausschließlich im Store. UserDefaults speichert weiterhin nur Preferences und Bookmark-Metadaten (nicht-Inhaltsdaten); Token-only via Keychain.
- **Serverupload bleibt strikt getrennt und opt-in.** Der bestehende, optional aktivierbare Live-Upload (`NSPrivacyCollectedDataTypePreciseLocation`) ist **nicht** mit dem Importpfad verbunden. Importdaten werden **nicht** in den Upload-Pfad geleitet — der Store-Pfad hat keinen Hook auf `LiveLocationServerUploadConfiguration`.
- **DB ist regenerierbarer Cache und vom Backup ausgeschlossen.** `LocalTimelineFileAttributes` setzt `URLResourceKey.isExcludedFromBackupKey = true` auf DB-Verzeichnis und DB-Datei. Quelldatei bleibt Source of Truth (Bookmark-basierter Re-Import).
- **FileProtection-Ziel**: `completeUnlessOpen` (Live-Activity-kompatibel). **Phase 4 hat den Hook nur dokumentiert, nicht aktiviert.** Vor produktivem Rollout muss `URLResourceKey.fileProtectionKey` (oder `SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN` an `sqlite3_open_v2`) auf Apple-Plattformen tatsächlich gesetzt und in einem Darwin-Hardware-Pass verifiziert werden.
- **Löschmöglichkeit für Nutzer (Engineering-Pflicht vor produktivem Rollout)**: Phase 4 stellt `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData(store:)` zur Verfügung — löscht in einer Operation DB + WAL + SHM + RenderCache + ImportStaging + ExportStaging und ist idempotent; Phase 6 wrappt das in `LocalTimelineDeletionService`; **Phase 7B** ergänzt mit `LocalTimelineDeletionPresentation` eine Service-/Presentation-Schicht über dem Service. Im Store-Pfad ist **kein Bookmark-/Preferences-Cleanup nötig** (keine UserDefaults für Standortdaten — dokumentiert in `LocalTimelineDeletionService` und `LocalTimelineDeletionPresentation`). Der **produktive Settings-Button** „Importierte Daten löschen" (Wrapper/SwiftUI-Wiring) bleibt **Phase 8** und ist offen vor UI-Aktivierung.
- **Keine Änderung an `NSPrivacyCollectedDataTypes`**, solange der Store lokal-only bleibt. Apple-PrivacyInfo-Modell behandelt reines on-device-Storage nicht als „Data Collection". Sobald sich Speicherort, Backup-Strategie oder Datenfluss ändern (z. B. Sync, Drittweitergabe), ist eine Aktualisierung dieses Abschnitts und von `docs/privacy.html` Pflicht **vor** TestFlight-Resubmit.
- **Status**: Spike/pre-production, nicht UI-aktiv. Kein produktiver App-Flow nutzt den Store. Kein DayList/DayDetail/Map-Hook, kein Export-Umbau, kein `AppExport` über den Store-Pfad.

---

## 5. Stand-Zusammenfassung

| Aspekt | Status | Verifikationsort |
|---|---|---|
| Kein Cross-App-Tracking | ✅ belastbar | PrivacyInfo.xcprivacy + Code |
| Location-Usage-Keys vorhanden | ✅ belastbar | Info.plist |
| Upload standardmäßig deaktiviert | ✅ belastbar | Code (LiveLocationServerUploadConfiguration) |
| Upload HTTPS-only | ✅ belastbar | Code (endpointURL-Getter) |
| Bearer-Token im Keychain | ✅ belastbar | Code (AppPreferences, KeychainHelper) |
| Kein Hardcode-Endpunkt | ✅ belastbar | Code (defaultTestEndpointURLString = "") |
| NSPrivacyCollectedDataTypes im Manifest eingetragen | ✅ belastbar | PrivacyInfo.xcprivacy |
| Apple-Review-Einordnung dieser Deklaration | ⚠️ offen | benötigt Apple-Feedback / Store-Review |
| ZIPFoundation-Manifest-Compliance | ⚠️ offen | benötigt Apple-Host / xcodebuild |
| Datenschutzrichtlinien-URL | ✅ eingetragen (2026-04-30) | App Store Connect |
| Support-URL | ✅ eingetragen (2026-04-30) | App Store Connect |
| Fresh xcodebuild archive verifiziert | ⚠️ historisch (2026-03-17) | Apple-Host |
| End-to-End Upload auf Gerät | ✅ verifiziert (2026-04-02) | Apple-Host + echter Endpunkt |
