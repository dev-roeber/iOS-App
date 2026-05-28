# UI/UX Map-First Migration Plan

## 1. Status

- **Datum:** 2026-05-28
- **Train:** F.6 (Dokumentation), Vorbereitung fuer Train 2 (Migration) und Train 3 (Hardening).
- **Code-Aenderungen in Train 1/F.6:** keine.
- **Verbindlich ab Train 2** fuer iOS-26-iPhone-Pfad (`LGTabContainerView`).
- **Bezug:** `UI_UX_MAP_FIRST_LIQUID_GLASS_CONTRACT_2026-05-28.md`.

## 2. Inventur — Screens

| Screen | Karte | Bottom-Sheet | Heutiger Stil | Map-first geeignet | Glass-Komponenten heute | Risiken (i18n / A11y / Perf) |
|---|---|---|---|---|---|---|
| Welcome | nein | nein | Form-/Card-Mix | nein (Glass-Page) | teils LGGlassHelpers | A11y 100%; Source-Badges EN intentional |
| Map-Tab (Overview) | ja | ja (Explore-Sheet) | Hybrid | ja | LHMapBase, AppMapStyleResolver | Perf bei vielen Tracks; Layer-Pill 34pt |
| Days (Liste) | nein | nein | List/Form | nein (Glass-Page) | wenig | A11y 71% |
| DayDetail | ja | teils | Hero-Map + Cards | ja | LHHeroMapLayout, LHMapBase | A11y 71%; Card-Drift |
| Live (Inline) | ja | ja (LiveBottomSheet) | Map-first nahe Ziel | ja | LiveBottomSheet, LHMapBase | A11y 85%; Recording-Dual-Truth |
| Live (Fullscreen) | ja | nein | Map-first | ja | LHMapBase | s.o. |
| Insights | ja (Hero) | nein | Hero-Map + Mode-Filter | ja | LHHeroMapLayout | A11y 33% (kritisch); Mode/Filter-Coupling |
| Export | ja (Preview) | nein | Form + Preview-Map | teils (modal) | LHMapBase | A11y 67%; Render-Output abhaengig |
| Options | nein | nein | Form | nein (Glass-Page) | wenig | A11y 96% (gut) |
| iCloud-Options | nein | nein | Form | nein (Glass-Page) | wenig | A11y-Erbe von Options |
| Files | nein | nein | List | nein (Glass-Page) | wenig | i18n 14 Holes |
| Editor (Recorded Track) | ja (Workspace) | nein | Form + Map | teils | LHMapBase | Card-Drift; Track-Width 4.5 |
| Heatmap | ja | teils | Map-first | ja | LHMapBase | Perf (Render-Cap) |

## 3. Inventur — Karten (8 Map-Instanzen)

| # | Instanz | Aktuelle Komponente | MapKit-API | Overlays | Control-Stack | Layer-Pill | Bottom-Sheet | Attribution-Guard | TabBar-Clearance | Performance-Schutz |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | AppDayMapView | `AppDayMapView` | `Map` (SwiftUI) | `MapPolyline` Tracks + POIs | vorhanden | vorhanden | nein | teils | teils | mittel |
| 2 | AppOverviewTracksMapView (Compact) | `AppOverviewTracksMapView` | `Map` | Tracks-Overlay | vorhanden | vorhanden | nein direkt | teils | ja | mittel |
| 3 | AppOverviewTracksMapView (Explore-Sheet) | `AppOverviewTracksMapView` (Sheet) | `Map` | Tracks-Overlay | vorhanden | vorhanden | Sheet ist Host | teils | n/a | mittel |
| 4 | AppExportPreviewMapView | `AppExportPreviewMapView` | `Map` | Preview-Tracks | vorhanden | optional | nein (modal) | teils | n/a | gering |
| 5 | AppHeatmapView | `AppHeatmapView` | `Map` | Heatmap-Layer | vorhanden | vorhanden | teils | teils | teils | gering (Cap noetig) |
| 6 | AppLiveTrackingView (Inline) | `AppLiveTrackingView` | `Map` | Live-Track + Marker | vorhanden | vorhanden | LiveBottomSheet | ja | ja | mittel |
| 7 | AppLiveTrackingView (Fullscreen) | `AppLiveTrackingView` (Fullscreen) | `Map` | Live-Track + Marker | vorhanden | vorhanden | nein | ja | n/a | mittel |
| 8 | AppRecordedTrackEditorView | `AppRecordedTrackEditorView` | `Map` | Editor-Track + Handles | vorhanden | optional | nein (modal) | teils | n/a | mittel |

Track-Width-Drift heute: overview 3.0 / day 4.0 / editor 4.5 / export 5.0 / live 5.5. Konsolidierung siehe § 8.

## 4. Migrations-Phasen

### Phase A — Shared-Components implementieren

- Ziel: alle in § 5 des Contracts gelisteten Bausteine existieren und sind unit-/snapshot-getestet.
- Liefergegenstaende:
  - `LHMapFirstPageScaffold`
  - `LHMapWorkspace` + `LHMapWorkspaceConfiguration`
  - `LHMapFloatingChrome` (gruppiert via `GlassEffectContainer` / `LGGlassEffectGroup`)
  - `LHMapMetricCard`
  - `LHGlassBottomSheetDashboard`
  - `LHGlassPageScaffold`
  - `LHGlassSectionCard`
  - `LHMapPerformancePolicy` + Default-Profile
- Keine Konsumenten-Migration in dieser Phase. Bestehende Surfaces unveraendert.

### Phase B — Map-Screens migrieren

Reihenfolge (klein → gross, Risiko-aufsteigend dort wo sinnvoll):

1. **Live (Inline + Fullscreen)** — referenzhaft, da bereits Map-first nahe Ziel.
2. **DayDetail** — Hero-Map + Cards auf `LHMapFirstPageScaffold` + `LHGlassBottomSheetDashboard` + `LHMapMetricCard`.
3. **Insights-Hero** — Mode/Filter behalten, A11y-Coverage erhoehen.
4. **Map-Tab Hero** — Compact-Variante auf Scaffold.
5. **Export-Preview** — modal, Track-Width-Override dokumentieren.
6. **Heatmap** — Scaffold + Performance-Profil `heatmap`.
7. **Editor** — Workspace + Form-Modus via `LHGlassSectionCard`.
8. **Explore-Sheet** — Sheet bleibt Host, Inhalte auf Dashboard-Token.

Pro Screen tauschen: aussere Komposition + Chrome + Sheet. Bleiben: Camera-Controller, Datenquellen, Overlays, Business-Logik.

### Phase C — Nicht-Karten-Screens migrieren

- Welcome → `LHGlassPageScaffold` (Source-Badges EN bleiben intentional).
- Files → `LHGlassPageScaffold` + `LHGlassSectionCard`; 14 i18n-Holes schliessen.
- Options + iCloud-Options → `LHGlassPageScaffold`-Sections.
- Editor-Form-Modus → `LHGlassSectionCard`.

### Phase D — Performance-Hardening (Train 3)

- `LHMapPerformancePolicy`-Profile pro Surface scharf stellen.
- Viewport-Filter und Render-Caps fuer Overview/Heatmap.
- `onMapCameraChange(frequency:)` justieren.
- `mapInTreeWhenHidden`-Auswertung fuer modale Map-Surfaces.
- Recording-Dual-Truth aufloesen.
- MapLayerMenu-Hit-Region final ueberpruefen.

## 5. Risiko-Matrix

| Phase | Risiko | Frueh erkennen | Rollback |
|---|---|---|---|
| A | API-Drift in Scaffold-Signaturen | Konsumenten-freie Tests + Snapshot-Beispiele | Komponenten als internal markieren bis B startet |
| B | Camera-Closure-Bruch | Smoke-Test pro Screen | Screen einzeln auf Pre-Migration-Komposition zuruecksetzen |
| B | Sheet-Detents verdecken Attribution | Visuelle Inspektion + Inset-Assertion | Detent-Werte zurueck auf LHMapBase-Default |
| B | Track-Width-Drift sichtbar | Visual-Diff Export-Preview | Override-Token re-aktivieren |
| C | i18n-Regression bei Files/Options | `preferences.localized()`-Lint | Strings via Hotfix nachziehen |
| D | Performance-Profile zu aggressiv | Hitch-Profiling, FPS-Trace | Profil auf vorheriges Preset |
| D | Recording-Dual-Truth-Refactor bricht Live | Live-Smoke-Test | Onchange-Bruecke vorlaeufig reaktivieren |

## 6. Akzeptanzkriterien pro Phase

**Phase A:**
- `swift build` + `swift test` gruen.
- Alle neuen Komponenten haben mindestens einen Test (Init-Smoke + Token-Konsum).
- Keine Konsumenten-Aenderung.

**Phase B:**
- Pro migriertem Screen: visuelle Parity (Funktion erhalten), Attribution sichtbar, Chrome-Tap-Region >= 44 pt.
- Bestehende Tests gruen (`LHMapBase`, `LGGlassHelpers`, `RecentFilesStore`, sonstige Map-Tests).
- Kein Verlust dokumentierter Features.

**Phase C:**
- 17 bekannte i18n-Holes (14 Files + 3 LGTabContainerView) geschlossen.
- A11y-Coverage Files/Options nicht schlechter als heute.

**Phase D:**
- FPS-Median je Surface >= heutiger Wert.
- Recording-State Single-Truth.
- MapLayerMenu-Hit-Region >= 44 pt.

## 7. Test-Strategie

- **Pflicht-Gates pro PR:** `swift build`, `swift test`, `git diff --check`.
- **Bestehende Tests muessen gruen bleiben:** `LHMapBase`-Tests, `LGGlassHelpers`-Tests, `RecentFilesStore`-Tests, Map-Style-Resolver-Tests, Live-/DayDetail-Smoke-Tests.
- **Neue Tests in Phase A:**
  - Init-Smoke pro Komponente.
  - Token-Konsum-Assertion (Detents, Insets, Hairline).
  - Hit-Region-Assertion fuer `LHMapFloatingChrome`-Pills (>= 44 pt).
- **Neue Tests in Phase B:**
  - Pro migrierter Surface ein Komposition-Smoke (Scaffold mountet, Sheet detentiert, Attribution-Guard respektiert).
- **Phase D:**
  - Performance-Trace pro Profil (manuell + Instruments).
  - Single-Truth-Test fuer Recording-State.

## 8. Offene Fragen

1. **Track-Width-Vereinheitlichung — Phase A oder separater Train?** Empfehlung: Default 4.5 pt in Phase A einfuehren, Konsumenten ziehen in Phase B nach. Export-Override (5.0) dokumentiert als Render-Output-Begruendung.
2. **MapLayerMenu-Pill — Hit-Region in Phase A oder Phase D?** Empfehlung: Hit-Region (`.contentShape`) bereits in Phase A ueber `LHMapFloatingChrome`, visuelle Groesse spaeter optional.
3. **Insights Mode/Filter-Coupling** — gehoert in Phase B (Migration) oder Train 3 (Hardening)? Empfehlung: Entkopplung als separater Sub-PR in Train 3.
4. **Editor-Workspace im Modal** — eigener Performance-Policy-Eintrag noetig oder reicht `editor`-Profil? Klaerung in Phase B Screen-Migration.
5. **Pre-iOS-26-Pfad** — wann/ob Glass-Tokens fuer iPad-/Split-Pfad ausgerollt werden? Out-of-scope F.6, Diskussion nach Train 3.

## 9. Bekannte Restpunkte aus Audit (2026-05-27)

- **i18n-Holes:** 17 Strings — 14 in `AppFilesView`, 3 in `LGTabContainerView`. Welcome-Source-Badges EN sind intentional und ausgenommen.
- **MapLayerMenu-Pill 34×34 pt** — HIG-Verletzung. Fix via `LHMapFloatingChrome`-Hit-Region in Phase A; visuelle Anpassung optional.
- **Recording-Dual-Truth** — `recordButtonState` parallel zu `liveLocation.isRecording`, Sync via `onChange`. Aufloesen in Train 3.
- **Insights Mode/Filter-Coupling** — Mode-Wechsel triggert Filter-Reset. Entkopplung in Train 3.
- **A11y-Lueken:** Insights 33%, DayMap-Controls 25%, Export 67%, Days 71%. Schliessen waehrend jeweiliger Phase-B-Migration, harte Schwelle in Train 3.
- **Track-Width-Drift:** overview 3.0 / day 4.0 / editor 4.5 / export 5.0 / live 5.5 — konsolidieren auf 4.5 (Default) mit dokumentierten Overrides.
- **Card-Drift:** Mehrere lokale Card-Varianten in DayDetail, Insights, Editor, Export-Preview — Konsolidierung via `LHMapMetricCard` / `LHGlassSectionCard`.
- **Bottom-Sheet-Implementierungen:** Single Source soll `LiveBottomSheet` + `LHGlassBottomSheetDashboard` sein; Drift in Phase B beseitigen.
