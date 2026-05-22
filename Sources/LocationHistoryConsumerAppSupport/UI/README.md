# LHX* — additive UI-Foundation

Stand: 2026-05-22 · Branch `chore/full-app-redesign-foundation`.

Dieses Verzeichnis enthält die **additive** Komponentenbasis aus
`docs/APP_REDESIGN_INTERACTION_SPEC_2026-05-22.md` §4. Komponenten sind
neue SwiftUI-Views — sie ersetzen vorerst **keine** bestehenden Inline-
Implementierungen. Die schrittweise Adoption in Hub-Views erfolgt in den
Folge-Trains (C/D/E/G).

## Inhalt

| Komponente | Datei | Zweck |
|---|---|---|
| `LHXStatCard` | `LHXCards.swift` | Einzelmetrik (Icon · Label · Value · Unit). |
| `LHXActionCard` | `LHXCards.swift` | Card mit primärer + optional sekundärer Aktion. |
| `LHXInfoCard` | `LHXCards.swift` | Read-only Hinweis (`info` · `warning` · `error`). |
| `LHXSyncStatusCard` | `LHXCards.swift` | iCloud-Status-Card (Train F). |
| `LHXEmptyState` | `LHXStateViews.swift` | Standardisiertes Empty-State-Layout. |
| `LHXErrorState` | `LHXStateViews.swift` | Standardisiertes Error-State-Layout. |
| `LHXLoadingState` | `LHXStateViews.swift` | ProgressView + Phase-Label + optionaler Cancel. |
| `LHXPrimaryActionButton` | `LHXButtons.swift` | Primärer CTA mit Disabled-Reason. |
| `LHXSecondaryActionButton` | `LHXButtons.swift` | Sekundärer Button mit Disabled-Reason. |
| `LHXMapOverlayControl` | `LHXButtons.swift` | Floating Map-Overlay-Button. |

## Designprinzipien

1. **Additiv.** Keine bestehenden Views werden modifiziert; alte
   `LH*`-Komponenten bleiben Single-Source-of-Truth bis ihre Adoption-
   Trains entscheiden, welche `LHX*`-Variante sie ersetzt.
2. **DynamicType-resilient.** Mindestens 44 pt Tap-Targets,
   `.fixedSize(horizontal: false, vertical: true)` für Body-Text,
   `Spacer(minLength: 0)`-Strategie statt fixer Frames.
3. **Accessibility-first.** Jede Komponente bietet einen optionalen
   `accessibilityIdentifier`-Parameter, gruppiert via
   `accessibilityElement(.contain)` oder `.combine`, und reicht
   `disabledReason` als `accessibilityHint` durch.
4. **LH2GPXTheme-Tokens.** Farben kommen ausschließlich aus
   `LH2GPXTheme.*`; keine Hardcoded-Farben in den Komponenten.
5. **Wrap-up.** Cards nutzen den vorhandenen `View.cardChrome()`-
   Modifier, damit Border/Shadow/Padding mit `LHCard` konsistent sind.

## Was bewusst NICHT in diesem Train

- Adoption in `AppContentSplitView`, `AppExportView`,
  `AppInsightsContentView` o. ä. — wird in eigenen Trains C/D/E/G
  durchgeführt, jeweils mit Sichtprüfung + Tests.
- Light-/Dark-Modus-Anpassungen (Force-Dark bleibt heute Realität;
  Entscheidung steht aus, siehe Train A).
- Lokalisierung der Default-Texte — Komponenten sind String-agnostisch,
  Caller liefert lokalisierte Strings.
- Tests — *bewusst kein Test-Lauf* in dieser Phase; SwiftUI-View-Tests
  brauchen einen Apple-Host.

## Adoption-Checkliste pro Komponente (für Folge-Trains)

Wenn eine bestehende Inline-View durch eine `LHX*`-Komponente ersetzt
wird:

1. Bestehende Identifier (`days.searchField`, `export.primaryButton`,
   etc.) als `accessibilityIdentifier` an die `LHX*`-Komponente
   weitergeben.
2. Spacing/Padding 1:1 vergleichen (Stichprobenmessungen, weil
   `cardChrome` 16 pt Padding + 22 pt Radius hat).
3. Dynamic-Type-Kappe (`.dynamicTypeSize(.xSmall ... .xxLarge)`)
   in der konsumierenden View ergänzen, wenn Layout-Risiko besteht.
4. `swift test` lokal *und* `xcodebuild` Sim *und* Hardware-Smoke nach
   der Adoption — diese drei Schritte gehören in Train H.
