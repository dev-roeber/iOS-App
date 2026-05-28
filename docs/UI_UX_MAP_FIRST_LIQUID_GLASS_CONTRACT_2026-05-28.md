# UI/UX Map-First Liquid Glass Contract

## 1. Status & Geltungsbereich

- **Datum:** 2026-05-28
- **Train:** F.6 (Design-Contract, Dokumentation only)
- **Geltungsbereich:** iOS 26 iPhone-Pfad ueber `LGTabContainerView`.
- **Nicht im Scope dieser Migration:** Pre-iOS-26-Pfad und iPad-Pfad via `AppContentSplitView`. Dieser bleibt strukturell unangetastet; Verbesserungen, die sich aus Shared-Tokens automatisch ergeben (Hairline, Glass-Helfer), duerfen mitlaufen, sind aber kein Akzeptanzkriterium.
- **Status:** Verbindlich ab Train 2 fuer neue oder migrierte iOS-26-Surfaces. Bestehende Surfaces werden gemaess Migrationsplan ueberfuehrt.

## 2. Designziel

Die App ist eine **Karten-Anwendung mit Daten-Dashboard**, kein Formular-Tool mit Karten-Ornament. Das Liquid-Glass-Material ist die einzige Material-Sprache fuer Overlays, Sheets und Chrome; die Karte selbst bleibt die primaere visuelle Flaeche. Jede Map-Surface folgt demselben Map-First-Pattern: vollflaechige Karte, schwebendes Glass-Chrome, Bottom-Sheet als Daten-Dashboard. Nicht-Karten-Screens nutzen ein paralleles Glass-Page-Pattern, damit die App ein konsistentes Liquid-Glass-Material durchhaelt, ohne Karten zu faken.

## 3. Apple-Referenzen (canonical)

- Liquid Glass — Adopting Liquid Glass: https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass
- `GlassEffectContainer`: https://developer.apple.com/documentation/SwiftUI/GlassEffectContainer
- `glassEffect(_:in:isEnabled:)` modifier: https://developer.apple.com/documentation/SwiftUI/View/glassEffect(_:in:isEnabled:)
- `TabView`: https://developer.apple.com/documentation/SwiftUI/TabView
- `tabViewBottomAccessory(content:)`: https://developer.apple.com/documentation/SwiftUI/View/tabViewBottomAccessory(content:)
- MapKit for SwiftUI Overview: https://developer.apple.com/documentation/MapKit/mapkit-for-swiftui
- `Map`: https://developer.apple.com/documentation/MapKit/Map
- `MapPolyline`: https://developer.apple.com/documentation/MapKit/MapPolyline
- `MapCameraPosition`: https://developer.apple.com/documentation/MapKit/MapCameraPosition
- `onMapCameraChange(frequency:_:)`: https://developer.apple.com/documentation/MapKit/Map/onMapCameraChange(frequency:_:)
- HIG Maps: https://developer.apple.com/design/human-interface-guidelines/maps
- HIG Buttons: https://developer.apple.com/design/human-interface-guidelines/buttons
- HIG Layout: https://developer.apple.com/design/human-interface-guidelines/layout
- HIG Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Xcode Performance Profiling: https://developer.apple.com/documentation/Xcode/improving-your-app-s-performance
- Diagnosing Animation Hitches: https://developer.apple.com/documentation/Xcode/diagnosing-performance-issues-early

## 4. Architektur-Schichten

Drei klar getrennte Ebenen. Hoehere Ebenen duerfen nur ueber dokumentierte Tokens auf tiefere zugreifen.

| Ebene | Zweck | Bausteine |
|---|---|---|
| (a) Map-First Page-Shell | Vollflaechige Karte + Floating-Chrome + Bottom-Sheet | `LHMapFirstPageScaffold`, `LHMapWorkspace`, `LHMapFloatingChrome`, `LHGlassBottomSheetDashboard`, `LHMapMetricCard` |
| (b) Glass Page-Shell (Nicht-Karten) | Standard-Form-/Listen-Screens im Glass-Look | `LHGlassPageScaffold`, `LHGlassSectionCard` |
| (c) Shared Tokens | Single Sources fuer Material, Insets, Stil | `LHMapBase`, `LGGlassHelpers`, `LH2GPXTheme.LiquidGlass`, `AppMapStyleResolver`, `LHMapPerformancePolicy` |

Regeln:
- Ebene (a)/(b) **konsumieren** ausschliesslich Tokens aus (c). Keine Duplikate.
- Neue Tokens werden in (c) ergaenzt, nicht inline.
- Ebene (a) darf Ebene (b)-Bausteine **nicht** mounten und umgekehrt.

## 5. Komponenten-Contract

Pro Komponente: Verantwortung, Public-Init-Schema (nur Signatur-Sketch, kein Code), Plattform-Gate, Fallback.

### 5.1 `LHMapFirstPageScaffold<MapContent, SheetContent>`

- **Verantwortung:** Root-Container fuer eine Map-First-Surface. Stapelt Karte (full bleed), Floating-Chrome und Bottom-Sheet. Vermittelt Detents, SafeArea, TabBar-Clearance.
- **Init-Sketch:** `init(configuration: LHMapFirstPageConfiguration, @ViewBuilder map: () -> MapContent, @ViewBuilder sheet: () -> SheetContent)`
- **Plattform-Gate:** `@available(iOS 26, *)`.
- **Fallback:** Auf aelteren OS-Versionen rendert der aufrufende Screen weiterhin die bisherige Komposition. Scaffold wird nicht gemountet.

### 5.2 `LHMapWorkspace`

- **Verantwortung:** Hostet die `Map`-Instanz inkl. Overlays, Camera-Position, `onMapCameraChange`-Bridge, Style-Resolver-Bindung. Controlled via Configuration-Struct.
- **Init-Sketch:** `init(configuration: LHMapWorkspaceConfiguration, overlays: LHMapOverlays, camera: Binding<MapCameraPosition>)`
- **Plattform-Gate:** iOS 26 (alle Map-Surfaces sind ohnehin iOS-17+; iOS-26-spezifisch wegen Glass-Integration im Eltern-Scaffold).
- **Fallback:** Reine `Map`-Komposition ohne Glass-Chrome bleibt fuer Fallback-Pfade nutzbar.

### 5.3 `LHGlassBottomSheetDashboard<Content>`

- **Verantwortung:** Bottom-Sheet als Daten-Dashboard ueber der Karte. Drei Detents (collapsed/medium/expanded), Liquid-Glass-Hintergrund via `LGGlassHelpers.lgGlassSurface`, automatische TabBar-Clearance ueber `LHMapBase.bottomSheetTabBarClearance(...)`.
- **Init-Sketch:** `init(detents: LHSheetDetents, initialDetent: LHSheetDetent, bottomClearance: CGFloat, @ViewBuilder content: () -> Content)`
- **Plattform-Gate:** iOS 26.
- **Fallback:** Bestehendes `LiveBottomSheet` bleibt fuer Live-Tracking unveraendert; neue Surfaces nutzen das Dashboard direkt.

### 5.4 `LHMapFloatingChrome`

- **Verantwortung:** Linke Layer-Pill (basierend auf `LHMapBase.layersBadge(activeCount:)`) und rechter Control-Stack. Wrapped einen `GlassEffectContainer` / `LGGlassEffectGroup`, damit alle Pills wie eine Glass-Gruppe morphen.
- **Init-Sketch:** `init(layers: LHLayersDescriptor, controls: [LHFloatingControl], topInset: CGFloat)`
- **Hit-Region zwingend 44pt** (siehe HIG-Hartregeln). Visuelle Pill kann kleiner sein, Tap-Flaeche via `.contentShape`.
- **Plattform-Gate:** iOS 26.
- **Fallback:** Keiner — Komponente wird nur in iOS-26-Surfaces eingesetzt.

### 5.5 `LHMapMetricCard`

- **Verantwortung:** Einheitliche Kennzahl-Karte (Icon + Label + Wert + optional Tint). Ersetzt driftende Card-Varianten in DayDetail, Insights, Editor, Export-Preview.
- **Init-Sketch:** `init(icon: Image, label: String, value: String, tint: Color? = nil, accessibilityValue: String? = nil)`
- **Plattform-Gate:** iOS 26 (visuell). Tokens duerfen in aelteren Pfaden mit Material-Fallback wiederverwendet werden.
- **Fallback:** Bestehende Cards bleiben in Nicht-iOS-26-Pfaden.

### 5.6 `LHGlassPageScaffold<Content>`

- **Verantwortung:** Glass-Equivalent zur `NavigationStack { Form { ... } }`-Struktur fuer Nicht-Karten-Screens.
- **Init-Sketch:** `init(title: String, @ViewBuilder content: () -> Content)`
- **Plattform-Gate:** iOS 26.
- **Fallback:** Bestehende `Form`/`List`-Layouts.

### 5.7 `LHGlassSectionCard<Content>`

- **Verantwortung:** Sektion innerhalb `LHGlassPageScaffold`. Card-Token mit Hairline-Stroke, Glass-Surface, einheitlichem Padding.
- **Init-Sketch:** `init(title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content)`
- **Plattform-Gate:** iOS 26.
- **Fallback:** Standard-`Section` in `Form`.

### 5.8 `LHMapPerformancePolicy`

- **Verantwortung:** Deklarative Performance-Strategie pro Map-Surface. Wird vom `LHMapWorkspace` konsumiert.
- **Init-Sketch:** `struct LHMapPerformancePolicy { var renderPointCap: Int; var viewportFilteringEnabled: Bool; var lod: LHMapLOD; var onMapCameraChangeFrequency: MapCameraUpdateFrequency; var mapInTreeWhenHidden: Bool }`
- **Default-Profile (vorgeschlagen, nicht normativ):** `live`, `dayDetail`, `overview`, `insights`, `export`, `heatmap`, `editor`.
- **Plattform-Gate:** iOS 26 fuer Frequency-Bridge; Felder funktional auch unter Fallback.

## 6. Token-Konstanten

Zentral in `LHMapBase` und `LH2GPXTheme.LiquidGlass`. Aufrufende Views holen sich ausschliesslich von dort.

| Token | Wert | Quelle |
|---|---|---|
| Floating-Control Top-Gap | 12 pt | `LHMapBase.floatingControlTopInset(deviceTopSafeInset:)` |
| Floating-Control Side-Inset | 12 pt | `LHMapBase.floatingControlSideInset` |
| Attribution-Guard Bottom-Inset | 32 pt | `LHMapBase.attributionGuardBottomInset` |
| TabBar-Standard-Hoehe | 49 pt | `LHMapBase.tabBarStandardHeight` |
| Bottom-Sheet Detents portrait | 140 / 240 / 360 | LHMapBase |
| Bottom-Sheet Detents compact | 160 / 320 / 520 | LHMapBase |
| Bottom-Sheet Detents landscape | 140 / 200 / 280 | LHMapBase |
| Track-Width Default | 4.5 pt | `MapTrackStyle.Width` (neuer Default) |
| Halo Multiplier | 1.85x | `MapTrackStyle.haloMultiplier` |
| Halo Opacity | 0.28 | `MapTrackStyle.haloOpacity` |
| Map-Hero compact | 460 pt | `LHHeroMapLayout.compactHeight` |
| Map-Hero expanded | 560 pt | `LHHeroMapLayout.expandedHeight` |
| Hairline | `LH2GPXTheme.LiquidGlass.hairline` | Theme |

**Track-Width-Kanon:** 4.5 pt wird neuer einheitlicher Default. Per-Context-Override nur mit Begruendung im PR-Body (z. B. Export benoetigt staerkere Linie fuer Render-Output). Aktueller Drift (3.0/4.0/4.5/5.0/5.5) wird konsolidiert (Migrationsplan, offene Frage in Doc 2 § 8).

## 7. HIG-Hartregeln

1. **Tap-Targets >= 44 pt** als Hit-Region. Visuelle Pill darf kleiner sein, wenn `.contentShape(Rectangle())` 44×44 abdeckt. MapLayerMenu-Pill (heute 34×34 pt) ist Verletzung und wird ueber `LHMapFloatingChrome` korrigiert.
2. **Apple-Maps-Attribution darf nie verdeckt werden.** Bottom-Sheet-Detents und Floating-Chrome respektieren `attributionGuardBottomInset`.
3. **Color-Only-Information verboten.** Jedes farbcodierte Affordance (z. B. Track-Tint, Layer-State) benoetigt sekundaeren Indikator (Icon, Symbol, Text).
4. **Dynamic Type:** `.font(.system(size:))` nur fuer Glyphen/Icons, niemals fuer Lesetext. Lesetext nutzt semantische Text-Styles.
5. **GlassEffectContainer-Gruppierung:** Benachbarte Glass-Affordances (z. B. Control-Stack) werden gruppiert, damit Liquid-Glass-Morphing korrekt funktioniert.

## 8. Map-Screen-Contract

| Surface | Layer-Pill | Control-Stack | Attribution-Guard | Sheet+TabBar-Clearance | Performance-Profil | Empf. Track-Width |
|---|---|---|---|---|---|---|
| AppDayMapView | MUSS | MUSS | MUSS | MUSS | `dayDetail` | 4.5 |
| AppOverviewTracksMapView (Compact) | MUSS | MUSS | MUSS | MUSS | `overview` | 4.5 |
| AppOverviewTracksMapView (Explore-Sheet) | MUSS | MUSS | MUSS | n/a (Sheet ist Host) | `overview` | 4.5 |
| AppExportPreviewMapView | optional | MUSS | MUSS | n/a (modal) | `export` | 5.0 (Override: Render-Output) |
| AppHeatmapView | MUSS | MUSS | MUSS | MUSS | `heatmap` | n/a (Heat) |
| AppLiveTrackingView (Inline) | MUSS | MUSS | MUSS | MUSS (LiveBottomSheet) | `live` | 4.5 |
| AppLiveTrackingView (Fullscreen) | MUSS | MUSS | MUSS | n/a | `live` | 4.5 |
| AppRecordedTrackEditorView | optional | MUSS | MUSS | n/a (modal) | `editor` | 4.5 |

Alle Surfaces nutzen `AppMapStyleResolver` als Single Source.

## 9. Nicht-Karten-Screen-Contract

Folgende Screens werden auf `LHGlassPageScaffold` + `LHGlassSectionCard` umgestellt; **keine Fake-Karte**, kein dekoratives Map-Snippet:

- `AppShellWelcomeView`
- `AppFilesView`
- `AppOptionsView` (inkl. Sub-Sektionen)
- `AppICloudOptionsView`
- Editor im Form-Modus (sofern kein Map-Workspace aktiv)

Konventionen:
- Titel via `LHGlassPageScaffold(title:)`.
- Gruppen via `LHGlassSectionCard`.
- Kein Inline-`Form` mehr in Glass-Surfaces.
- Lokalisierungspflicht (siehe § 10).

## 10. Verbotene Patterns

- Inline `.ultraThinMaterial` ohne `LH2GPXTheme.LiquidGlass.hairline`-Stroke.
- Hartcodierte Track-Widths ausserhalb `MapTrackStyle.Width`. Override nur dokumentiert.
- Eigene Bottom-Sheet-Implementierungen ausserhalb `LiveBottomSheet` und `LHGlassBottomSheetDashboard`.
- Inline `Color.white.opacity(...)` als Surface-Background. Stattdessen `lgGlassSurface` / `lgGlassPill` / `lgGlassCircle`.
- Hartcodierte deutsche/englische User-facing-Strings ohne `preferences.localized()`. Ausnahmen nur intentional (z. B. Welcome-Source-Badges EN).
- Direkter Zugriff auf `Color`-Literale fuer semantische Rollen — stattdessen Theme-Tokens.

## 11. Migrationsregeln

1. **Keine Funktion entfernen.** Migration ist visuelle/strukturelle Konsolidierung, keine Feature-Reduktion.
2. **Camera-Closures wiederverwenden.** `AppDayMapCameraController` und vergleichbare Controller bleiben Source of Truth fuer Camera-Logik.
3. **Pre-iOS-26-Pfad (`AppContentSplitView`) bleibt unangetastet.**
4. **Tests gruen vor und nach Migration.** `swift build` + `swift test` als Gate.
5. **Kein Doppel-State.** Bekanntes Recording-Dual-Truth-Anti-Pattern (`recordButtonState` parallel zu `liveLocation.isRecording`) wird in Train 3 aufgeloest, nicht in F.6/Train 2.
6. **Glass-Migration zuerst, Performance-Hardening danach.** Reihenfolge gemaess Migrationsplan.

## 12. Governance

- **Owner:** iOS-Architekt-Rolle.
- **Aenderung des Contracts:** nur via PR an dieses Dokument, mit Begruendung, Apple-Referenz, Auswirkungs-Tabelle.
- **Review-Pflicht:** mindestens ein Reviewer mit Map-Surface-Kontext.
- **Versionierung:** Datumsstempel im Dateinamen wird bei Major-Revisionen erhoeht (neue Datei + Markierung der alten als „superseded").
- **Audit-Kadenz:** nach jedem abgeschlossenen Train pruefen, ob Contract noch vollstaendig die Realitaet beschreibt; sonst nachziehen.
