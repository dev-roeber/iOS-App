# Phase C Map Controls + Resize Audit - 2026-05-25

## Scope

Phase C is expected to cover two user-facing map interaction areas:

- Global map options exposed through SwiftUI-native controls, including map style/layer choices and related display toggles.
- Resizable map cards/headers where the user can drag to adjust map height while preserving usable map interaction and surrounding layout stability.

This audit documents the Phase C implementation. Swift map/control files, localization resources, and status docs were edited; tests, CloudKit, Favorites, iPad build settings, Xcode Cloud, and TestFlight were not touched.

## Official Apple Docs Checked

- SwiftUI `DragGesture`: confirms the intended pattern for a view-local dragging motion that reports change and end events through gesture modifiers. Relevant to resizable map card handles and height adjustment.
  - https://developer.apple.com/documentation/swiftui/draggesture
- SwiftUI `Menu`: confirms `Menu` is the native compact control for presenting action groups, submenus, labels, and adaptive menu content. Relevant to global map options without building custom popover behavior.
  - https://developer.apple.com/documentation/swiftui/menu
- MapKit SwiftUI `Map`: confirms SwiftUI `Map` supports embedded maps, content such as markers/annotations/overlays, map interaction modes, styles, and system map controls. Relevant to preserving map behavior while adding options and resize affordances.
  - https://developer.apple.com/documentation/mapkit/map
- SwiftUI `accessibilityAdjustableAction(_:)`: confirms adjustable actions can expose increment/decrement behavior to assistive technologies. Relevant to map height changes that should not depend only on drag input.
  - https://developer.apple.com/documentation/swiftui/view/accessibilityadjustableaction(_:)
- Apple HIG Gestures: confirms drag is a standard gesture for moving or adjusting UI elements, while tap activates controls and touch-and-hold reveals additional controls. Relevant to keeping resize drag, menu tap, and map gestures distinct.
  - https://developer.apple.com/design/human-interface-guidelines/gestures

## Expected Implementation Boundaries

- Use SwiftUI-native `Menu` or equivalent platform controls for global map options rather than custom menu chrome.
- Keep global map options scoped to map presentation controls, such as map style, points/overlays, tracking/visibility, or similar display choices already supported by the app.
- Use `DragGesture` only on an explicit resize affordance/handle so normal map pan, zoom, and annotation interactions remain available inside the map.
- Use the existing compact/expanded `LHMapHeaderState` heights rather than arbitrary freeform heights, so the map never collapses into an unusable target or consumes the entire surrounding workflow.
- Persist only the discrete compact/expanded state per screen; do not persist coordinates, viewport, routes, or other location data.
- Add accessibility labels/hints for resize controls and expose increment/decrement resizing through `accessibilityAdjustableAction`.
- Preserve Dynamic Type, VoiceOver, hit target, color contrast, and landscape behavior expectations.

## Explicit Non-Scope

- No CloudKit or iCloud sync changes.
- No Favorites model, storage, or UI changes.
- No iPad-specific redesign or multitasking layout expansion beyond avoiding regressions in existing responsive layout.
- No automated test implementation or execution in this phase.
- No unrelated map performance, location history, export, localization, or navigation refactors.

## Validation Plan

1. Build the app target in Xcode or via the repo's standard build command to catch SwiftUI/MapKit API mismatches.
2. Smoke-test global map options on a simulator/device:
   - Open each map surface that received the global options control.
   - Change every option and confirm the map updates without dismissing or corrupting surrounding state.
   - Reopen the view and confirm expected state behavior, whether local default or persisted by existing app conventions.
3. Smoke-test resizable map cards:
   - Drag the resize handle slowly and quickly.
   - Confirm compact/expanded states use the existing bounded map heights.
   - Confirm map pan/zoom still works when interacting inside the map body.
   - Confirm nearby scroll views, headers, and detail content do not jump or overlap.
4. Accessibility validation:
   - Run VoiceOver and confirm the menu, resize handle, and map controls have clear names.
   - Use adjustable actions on the resize handle and confirm increment/decrement changes are bounded and announced coherently.
   - Verify usable hit targets and readable labels under larger Dynamic Type sizes.
5. Regression pass:
   - Check portrait and landscape on iPhone.
   - Check existing map annotations/routes/overlays remain visible.
   - Confirm no CloudKit, Favorites, iPad-specific behavior, or unrelated screens changed as part of Phase C.

## Audit Result

Phase C is aligned with official Apple guidance when implemented as native SwiftUI menus plus explicit, bounded drag resizing with accessible adjustable alternatives. The phase should remain limited to global map presentation options and resizable map cards, with CloudKit, Favorites, iPad work, and automated tests treated as separate phases.
