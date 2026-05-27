#if canImport(XCTest) && canImport(SwiftUI)
import XCTest
import SwiftUI
@testable import LocationHistoryConsumerAppSupport

/// Body-compile + smoke tests fuer die LGGlassHelpers-Konvergenz.
/// SwiftUI ist auf Linux nicht verfuegbar (`canImport(SwiftUI)` gegated),
/// daher laufen diese Tests auf Apple-Plattformen. Auf Linux werden sie
/// uebersprungen — dort decken `LHMapBaseTests` und
/// `LiveBottomSheetClearanceTests` die Konstanten-Logik ab.
final class LGGlassHelpersTests: XCTestCase {

    // MARK: - lgGlassCircle

    func test_lgGlassCircle_defaultDiameter_compiles() {
        let view = Text("●").lgGlassCircle()
        XCTAssertNotNil(view.body)
    }

    func test_lgGlassCircle_customDiameter_compiles() {
        let view = Image(systemName: "scope").lgGlassCircle(diameter: 44)
        XCTAssertNotNil(view.body)
    }

    // MARK: - lgGlassSurface

    func test_lgGlassSurface_defaultRadius_compiles() {
        let view = Text("Glass").lgGlassSurface()
        XCTAssertNotNil(view.body)
    }

    func test_lgGlassSurface_customRadius_compiles() {
        let view = Text("Glass").lgGlassSurface(cornerRadius: 10)
        XCTAssertNotNil(view.body)
    }

    // MARK: - lgGlassPill

    func test_lgGlassPill_plain_compiles() {
        let view = Text("Pill").lgGlassPill()
        XCTAssertNotNil(view.body)
    }

    func test_lgGlassPill_tinted_compiles() {
        let view = Text("Tinted").lgGlassPill(tint: .accentColor)
        XCTAssertNotNil(view.body)
    }

    // MARK: - LHGlassMaterial forwards (deprecated)

    @available(*, deprecated, message: "Covers the deprecated forward path explicitly.")
    func test_lhGlassControlPill_forwardsToLgGlassCircle() {
        let view = Image(systemName: "scope").lhGlassControlPill()
        XCTAssertNotNil(view.body)
    }

    // MARK: - LGGlassEffectGroup

    func test_LGGlassEffectGroup_passthroughBody_compiles() {
        let group = LGGlassEffectGroup(spacing: 8) {
            Text("A")
            Text("B")
        }
        XCTAssertNotNil(group.body)
    }
}
#endif
