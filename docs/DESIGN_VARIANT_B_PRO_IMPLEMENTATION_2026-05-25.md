# Design Variant B Pro · Implementation Notes — 2026-05-25

**Quelle:** `variant-b-pro.html` (LH2GPX · Topographic Outdoor · Pro · iOS 26 Liquid Glass).
**HEAD geprüft:** `81a78c4` · **Scope:** build-only Adoption der Design-Sprache + erweiterte iCloud-Settings. **Tests deferred bis Punkt 10.**

## 1. Designziele (übernommen aus HTML)

- **Map-first / map-as-interface** — Karte als zentrale Oberfläche, Bedienelemente als Glass-Sheets/Cards.
- **Topographic Outdoor** — warme Dark-Outdoor-Oberflächen, terra/moss/teal/azure-Akzente.
- **iOS 26 Liquid Glass** — sichtbares Glass-Material, spekulare Top-Highlights, weiche Schatten.
- **5-Tab-Konzept** — Map · History · Record · Stats · More (konzeptionelle Zielstruktur).
- **Record/Live** zentral, auffälliger Zustand mit dediziertem Rot.

## 2. Design-Tokens (aus HTML extrahiert)

### Surface Layers
| Token | Hex/RGBA |
|---|---|
| `bg-base` | `#0A0807` (deepest) |
| `bg-shell` | `#14100D` (phone shell) |
| `bg-warm` | `#1A1612` (warm card base) |
| `bg-elev-1/2/3` | `rgba(255,237,213, .04/.06/.09)` |
| `bg-glass` | `rgba(20,16,13, .62)` |
| `bg-glass-deep` | `rgba(10,8,7, .82)` |

### Hairlines & Text
| Token | Wert |
|---|---|
| `hair-1/2/3` | `rgba(255,237,213, .06/.10/.16)` |
| `hair-spec` (specular highlight) | `rgba(255,237,213, .22)` |
| `t-1` (cream-50) | `#FBF1E0` |
| `t-2/3/4` | `rgba(251,241,224, .66/.42/.22)` |

### Brand (Terra-Familie)
| Token | Hex |
|---|---|
| `terra-50/100/300/500/700` | `#FFD5BD` · `#FFB48E` · `#FF9966` · `#F47B4D` · `#D85F37` |

### Semantic
| Token | Hex | Verwendung |
|---|---|---|
| `moss` / `moss-d` | `#C7FA60` / `#9DD13A` | Trails, positive |
| `teal` | `#5EE3CC` | Wasser, long-distance |
| `azure` | `#66A8FF` | Himmel, GPS |
| `plum` | `#C977F3` | Bike |
| `red` / `red-d` (recording) | `#FF3B5C` / `#E0223E` | Recording active |
| `amber` | `#FFB547` | Warning |

### Radii
| Token | Wert |
|---|---|
| `r-card-lg` | 28 |
| `r-card-md` | 22 |
| `r-card-sm` | 16 |
| `r-pill` | 999 |

## 3. SwiftUI-Mapping

| HTML/CSS-Konzept | SwiftUI-Adaption |
|---|---|
| `--bg-base` body | `LH2GPXTheme.VariantBPro.bgBase` (`Color(red: 10/255, green: 8/255, blue: 7/255)`) |
| `backdrop-filter: blur(20px)` Glass | `.background(.ultraThinMaterial)` mit availability-Gate auf iOS 17+; iOS 26 `glassEffect` deferred |
| Hairline `0.5px` Border | `.overlay(RoundedRectangle().stroke(hair2, lineWidth: 0.5))` |
| `--shadow-card` inset specular | `.overlay(LinearGradient(...))` Top-Highlight + `.shadow(color: .black.opacity(0.5), radius: 24, y: 12)` |
| Fraunces serif italic display | `.font(.system(.largeTitle, design: .serif).italic())` (Fallback, siehe §5) |
| Geist sans body | `.font(.system(.body, design: .default))` |
| Geist Mono | `.font(.system(.caption2, design: .monospaced))` |
| `.r-card-lg` 28 | `RoundedRectangle(cornerRadius: 28, style: .continuous)` |

## 4. Was wird in diesem Train umgesetzt

### ✅ 1:1 übernommen
- Design-Tokens (Farben, Radii) als statische SwiftUI-Konstanten in `LH2GPXTheme.VariantBPro`.
- Glass-Material-Helper mit iOS-Availability-Gate.
- Token-Doku für spätere Adoption.

### ✅ Systemkonform adaptiert
- Liquid-Glass-inspirierte Materials via `SwiftUI Material` (`ultraThin`/`regular`/`thick`) — iOS 26 `glassEffect`/`GlassEffectContainer` deferred (API-Stabilität vor Push-Adoption).
- Fonts via System-Design-Rollen (`.serif`/`.default`/`.monospaced`) statt Google-Fonts-Bundle.

### ⏸️ Nur vorbereitet / deferred
- **Tab-Remap auf 5 Tabs Map/History/Record/Stats/More** — bestehende Tab-/Navigation-Struktur (Overview/Days/Live/Insights/Export/Settings via `AppContentSplitView`) bleibt. Vollständiger Remap würde Navigation/Routing/Bookmarks brechen und ist ein eigener Train.
- **Map-first Hero-Layout mit Bottom-Sheet** — bestehende Map-Views (`AppDayDetailView`, `AppHeatmapView`, `AppOverviewTracksMapView`) bleiben funktional unverändert; Token-Adoption ist gradueller Follow-up.
- **Record-FAB mit Pulse-Animation** — vorhanden über `LiveLocationFeatureModel`; Visual-Polish-Adaption ist Follow-up.

### ❌ Bewusst nicht übernommen
- **Externe Webfonts (Fraunces / Geist / Geist Mono)** — keine Lizenzverletzung, kein Asset-Bundling, kein Download. System-Fallback dokumentiert.
- **CSS-only Animationen ohne Accessibility-Check** — alle SwiftUI-Animationen müssen `reduceMotion`-konform sein.
- **HTML-Dummy-Daten** — keine UI ohne echte Datenquelle.
- **Funktionserweiterungen ohne Codepfad** — alle UI-Controls müssen einer realen Action zugeordnet sein.

## 5. Font-Strategie (verbindlich)

| HTML-Rolle | SwiftUI-Fallback | Begründung |
|---|---|---|
| Fraunces (serif italic display) | `.font(.system(.largeTitle, design: .serif).italic())` | Apple SF Serif ist lizenzfrei verfügbar, optisch nah |
| Geist (sans body) | `.font(.system(.body))` (San Francisco) | SF ist iOS-Default, exzellente Lesbarkeit |
| Geist Mono | `.font(.system(.caption2, design: .monospaced))` (SF Mono) | SF Mono ist iOS-Default |

**Keine** Google-Fonts werden heruntergeladen, **keine** Font-Dateien werden ins Repo gecheckt. Falls später echte Fonts gewünscht: separater Lizenz-/Bundling-Train mit OFL-Check.

## 6. Funktionsschutz (bestätigt)

Alle bestehenden Features bleiben unverändert funktional:
- Import (Google Timeline + LH2GPX-Export + GPX + TCX), Auto-Restore, Bookmark-Persistence.
- Export (GPX/KMZ/KML/GeoJSON/CSV), Files/iCloud-Drive-Hint, fileExporter.
- Live Tracking + Live Upload + Keychain-Token.
- Heatmap + Insights + Day Detail + Timeline.
- Widget + Live Activity + Dynamic Island.
- iCloud AccountStatus (CKContainer-Adapter, ohne Records).
- App Intents (3 Open-Intents).

**Keine** Identifier entfernt. **Keine** Layout-Routing-Änderung.

## 7. iCloud-Sync-Einstellungen (neu in diesem Train)

| Preference | Default | Wirkung |
|---|---|---|
| `iCloudSyncEnabled` (Bestand) | `false` | Master-Toggle; triggert `CKContainer.accountStatus()` via `CloudSyncService` |
| **`syncLiveTrackMetadataEnabled`** (neu) | `false` | Vorbereitungs-Gate für `LiveTrackMeta`-Schema-Adoption; **schreibt keine Records** bis Sync-Engine-Train |
| **`iCloudStatusAutoRefreshEnabled`** (neu) | `false` | Konservativer Default; wenn `true`, refresht `CKContainer.accountStatus()` bei jeder Sicht auf den iCloud-Settings-Screen (bestehender `task`-Hook) |
| **`iCloudSyncAllowCellular`** (neu) | `false` | Gate für spätere Sync-Engine (WLAN-only Default) |
| **`iCloudSyncConflictPolicy`** (neu) | `.manual` | Enum (manual / preferLocal / preferCloud); nur gespeichert + angezeigt, noch nicht angewendet |
| `preferCloudDriveExport` (Bestand) | `false` | Cosmetic Export-Hint (F.3) |

**Code-Belege:**
- `AppPreferences.swift` Keys + `@Published` + `init` + `reset`.
- `AppICloudOptionsView.swift` zeigt alle 6 Preferences in strukturierten Settings-Cards.
- `CloudKitCloudSyncService` bleibt auf `accountStatus()` beschränkt — **keine** save/fetch/query/delete.

## 8. Anti-Claims (verbindlich nach diesem Train)

- ❌ Echter iCloud-Sync implementiert.
- ❌ Records werden geschrieben/gelesen.
- ❌ Historien-Synchronisation aktiv.
- ❌ Automatischer Upload aus Import/Export.
- ❌ Public/Shared CloudKit-Database.
- ❌ CKSubscription/CKAsset/CKQuery.
- ❌ Cellular-Policy hat Effekt (nur Preference-Gate).
- ❌ Conflict-Policy wird angewendet (nur Preference-Gate).
- ❌ Neue Fonts bundled.
- ❌ Tab-Remap durchgeführt.
- ❌ iPad/Light-Mode aktiviert.
- ❌ Neuer Xcode-Cloud-Build > 190; letzter extern grüner Stand bleibt **190** auf `b25c27d`.
- ❌ Neue PrivacyInfo-Reasons (keine neuen API-Aufrufe).
- ❌ Tests ausgeführt (deferred bis Punkt 10).

## 9. Build-only Status

| Check | Erwartung |
|---|---|
| `swift build` | ✅ 0E/0W |
| `xcodebuild` Sim build | ✅ BUILD SUCCEEDED |
| `xcodebuild` generic iOS build | ✅ BUILD SUCCEEDED |
| `plutil -lint` PrivacyInfo | ✅ OK |
| Sweeps (CloudKit/Secret/Claim/Placeholder) | ✅ keine neuen Risiken |

## 10. Nächste Schritte

1. **Build-only Design-Follow-up** (optional): graduelle Token-Adoption in einzelnen Screens (DayDetail, Heatmap, Settings).
2. **Build-only Tab-Remap-Train** (deferred): saubere Migration auf 5-Tab-Struktur Map/History/Record/Stats/More mit Routing-Tests vor Punkt 10.
3. **Sync-Engine-Train** (deferred, NACH Punkt 10): `LiveTrackMeta`-Records schreiben/lesen via `privateCloudDatabase`, Anwendung der `iCloudSyncConflictPolicy`, `iCloudSyncAllowCellular`-Gate.
4. **Punkt 10**: vollständige Tests + Xcode Cloud + TestFlight.
