import XCTest

/// Source-level presence + invariant tests for the B-5.5 per-screen
/// detent profiles on `LHSheetDetents`. SwiftUI is not available on
/// Linux so the runtime profiles are not instantiable here; we assert
/// on the source file directly.
final class LHSheetDetentsProfilesTests: XCTestCase {

    private func detentsSource() throws -> String {
        let testFile = URL(fileURLWithPath: #file)
        let url = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LocationHistoryConsumerAppSupport")
            .appendingPathComponent("LHGlassBottomSheetDashboard.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func test_perScreenProfiles_arePresent() throws {
        let source = try detentsSource()
        for profile in ["mapTab", "live", "dayDetail", "insights", "export"] {
            XCTAssertTrue(
                source.contains("static let \(profile)"),
                "LHSheetDetents must expose `.\(profile)` profile after B-5.5."
            )
        }
    }

    func test_legacyProfiles_stillPresent() throws {
        let source = try detentsSource()
        for profile in ["portrait", "landscape", "compactPortrait"] {
            XCTAssertTrue(
                source.contains("static let \(profile)"),
                "Legacy `.\(profile)` profile must survive B-5.5."
            )
        }
    }
}
