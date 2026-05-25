# Localization DE/EN Audit — 2026-05-25 (Master · Phase B)

**HEAD geprüft:** `4d4cbcb` (Start) → wird gemerged mit Phase-B-Commit.

> **Phase B abgeschlossen.** Apple-modernes `.xcstrings` String Catalog als parallel-laufender Mirror der bestehenden `AppGermanTranslations`-Tabelle. **Kein** Breaking Change am `t(_:)`-Helper. **Keine** Tests ausgeführt (User-Direktive build-only).

## 1. Mechanik

| Layer | Status |
|---|---|
| `Package.swift` `defaultLocalization: "en"` | ✅ gesetzt |
| `Sources/LocationHistoryConsumerAppSupport/Resources/Localizable.xcstrings` | ✅ NEU — 765 Keys |
| `Package.swift` Resource-Rule `.process("Resources")` für AppSupport-Target | ✅ gesetzt |
| Bestehender `AppLanguagePreference.localized(_:)` + `AppGermanTranslations` Dictionary | ✅ unverändert — bleibt single source of truth für App-Preference-Override |
| Bestehender `t(_:)`-Helper-Pattern in 668 Call-Sites | ✅ unverändert — keine Breaking Changes |

## 2. Coverage

- **xcstrings-Keys gesamt:** 765 (Apple-modern, base `en` + `de` voll übersetzt)
- **Quelle:** 750 Pairs aus `AppGermanTranslations.values` Dictionary + 37 hardcoded `Text("…")`-Strings aus LocalTimeline-Views (5 davon Duplikate)
- **Konflikt-Bereinigung:** 18 Case-insensitive Duplikate (z.B. „Day" vs „day") und 1 Swift-Reserved-Keyword („Type") aus xcstrings entfernt — bleiben aber in `AppGermanTranslations` für `t()`-Lookup
- **Zielsprachen:** `en` (Base), `de` (vollständig)

## 3. Wie die App jetzt lokalisiert

**Zwei parallel laufende Mechaniken:**

| Mechanik | Wirkung | Genutzt von |
|---|---|---|
| `AppLanguagePreference.localized(_:)` via `t("…")`-Helper → liest `AppGermanTranslations.values` | App-Preference-Override (User kann in App-Settings Deutsch wählen — auch auf englischem iOS-Device) | 668 Call-Sites in AppContentSplitView, AppExportView, AppOptionsView, AppInsightsContentView, AppLiveTrackingView, AppICloudOptionsView, AppDayDetailView, AppRecordedTrackEditorView, AppDayListView, wrapper ContentView |
| `Bundle.module.localizedString` via implizites `LocalizedStringKey` → liest `Localizable.xcstrings` | System-Locale-Lookup (greift wenn iOS-Device-Sprache deutsch ist) | 37 hardcoded `Text("…")`-Stellen in `LocalTimeline*`-Views (Phase-9/10A Tech-UI) |

**Warum zwei Mechaniken parallel:**
- `t()`-Helper ist app-internes Preference-Override (Apple's Bundle-Lookup ehrt nur System-Locale, nicht App-interne Settings).
- xcstrings ist Apple-konformer Translation-Workflow (XLIFF-Export, Xcode-UI-Editor) für zukünftige Übersetzer.
- LocalTimeline-Views haben aktuell keinen Zugriff auf `AppPreferences` (Phase-9/10A entworfen als eigenständige Tech-Views) — `LocalizedStringKey`-Mechanik ist hier der natürliche Migrationspfad.

## 4. Was NICHT migriert wurde (bewusst)

- `accessibilityIdentifier(...)`-Strings (UITest-Hooks)
- `UserDefaults`-Keys
- `enum rawValues` mit Persistenz
- CloudKit `recordType`/Field-Keys
- JSON-Keys / API Field Names
- File-Extensions (`gpx`, `kml`, …), UTType-Identifier
- Test-Fixture-Filenames
- Log-Categories
- Container-IDs (`iCloud.de.roeber.LH2GPXWrapper`)

## 5. Build-Verifikation

| Check | Ergebnis |
|---|---|
| JSON-Validität `Localizable.xcstrings` | ✅ 765 Keys, sourceLanguage=`en`, version=`1.0` |
| `swift build` | ✅ 53,9 s, 0 Warnings |
| `xcodebuild` iPhone-Sim build | ✅ BUILD SUCCEEDED |
| `xcodebuild` generic iOS build | ✅ BUILD SUCCEEDED |
| `git diff --check` | ✅ clean |

**AppIntents SSU-Artifact-Notice:** `appintentsnltrainingprocessor [...] Could not archive SSU artifacts` — bekannte Xcode-Notice bei String-Catalog-Erst-Adoption, KEIN Build-Failure (BUILD SUCCEEDED). Wird in Folge-Builds wenn AppIntents-Strings via xcstrings migriert sind verschwinden.

## 6. Was Phase B explizit NICHT gemacht hat

- ❌ Keine Migration der 668 bestehenden `t()`-Call-Sites auf `LocalizedStringResource` oder `String(localized:)` — bleibt bei bestehendem Pattern.
- ❌ Keine `InfoPlist.xcstrings` (Permission-Beschreibungen sind bereits in Info.plist als hardcoded deutsch+englisch via existierende Mechanik).
- ❌ Keine `Localizable.xcstrings` für `wrapper/LH2GPXWrapper`-Target (würde pbxproj-Surgery erfordern; bestehende `t()`-Mechanik liest weiter über AppSupport-Bundle).
- ❌ Keine `Localizable.xcstrings` für `wrapper/LH2GPXWidget`-Target (Widget hat eigenes `WidgetLocalizedStrings.swift`-System).
- ❌ Kein Code-Change in den 37 LocalTimeline-View-Strings — sie sind bereits implizit `LocalizedStringKey` via `Text("…")`-Syntax und werden auf deutschen iOS-Geräten über xcstrings übersetzt.
- ❌ Keine Tests ausgeführt (User-Direktive).
- ❌ Keine CloudKit-/Favoriten-/iPad-Arbeit (Phasen D/E/F).

## 7. Verifikations-Plan (für späteren Test-Train)

- `LocalizationXCStringsParityTests.swift`: jede `AppGermanTranslations`-Übersetzung auch in `Localizable.xcstrings` vorhanden (außer 17 absichtlich entfernte Konflikte).
- `LocalizationKeyAuditTests.swift`: jeder `t("…")`-Call-Site Key ist in `AppGermanTranslations` als englischer Key vorhanden.
- Sim-UITests: deutsche Localization-Snapshot pro Tab.
- Device-Test mit deutschem iOS: LocalTimeline-Views zeigen deutsche Strings.

## 8. Nächster Schritt

**Phase C (gemäß User-Update vom 25.05.2026 eingeschoben):** Globales Karten-Optionsmenü auf allen Karten + Kartenhöhe compact/expanded steuerbar. Bisherige Phasen C–H rutschen nach D–I.
