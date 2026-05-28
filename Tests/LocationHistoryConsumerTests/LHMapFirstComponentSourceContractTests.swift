import XCTest

/// Source-level presence contract for the F.7 Phase-A shared components.
///
/// SwiftUI views cannot be instantiated on Linux (no SwiftUI symbol on the
/// platform), so we assert on the source files themselves: the canonical file
/// must exist in `Sources/LocationHistoryConsumerAppSupport/`, declare the
/// `public struct/enum` symbol, gate availability on iOS 26 where the contract
/// requires it, and reference the design-contract document.
final class LHMapFirstComponentSourceContractTests: XCTestCase {

    private func sourcesDirectory() -> URL? {
        // The test bundle lives next to `Sources/` inside the package root.
        // `#file` resolves to the test file at compile time; walk up to the
        // package root and into `Sources/LocationHistoryConsumerAppSupport`.
        let testFile = URL(fileURLWithPath: #file)
        let candidate = testFile
            .deletingLastPathComponent()         // .../Tests/LocationHistoryConsumerTests
            .deletingLastPathComponent()         // .../Tests
            .deletingLastPathComponent()         // .../<package root>
            .appendingPathComponent("Sources")
            .appendingPathComponent("LocationHistoryConsumerAppSupport")
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    private func read(_ relative: String) throws -> String {
        guard let root = sourcesDirectory() else {
            throw XCTSkip("Sources/ tree not reachable from this test bundle.")
        }
        let url = root.appendingPathComponent(relative)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func assertContract(
        file relative: String,
        symbolDeclaration symbolDecl: String,
        availabilityGate: String? = "@available(iOS 26.0, macOS 15.0, *)",
        contractAnchor: String = "UI_UX_MAP_FIRST_LIQUID_GLASS_CONTRACT_2026-05-28",
        line: UInt = #line
    ) throws {
        let source = try read(relative)
        XCTAssertTrue(
            source.contains(symbolDecl),
            "\(relative) must declare `\(symbolDecl)`.",
            line: line
        )
        if let gate = availabilityGate {
            XCTAssertTrue(
                source.contains(gate),
                "\(relative) must gate availability with `\(gate)`.",
                line: line
            )
        }
        XCTAssertTrue(
            source.contains(contractAnchor),
            "\(relative) must reference the design contract `\(contractAnchor)`.",
            line: line
        )
    }

    // MARK: - Map-first scaffold + workspace

    func test_LHMapFirstPageScaffold_present() throws {
        try assertContract(
            file: "LHMapFirstPageScaffold.swift",
            symbolDeclaration: "public struct LHMapFirstPageScaffold"
        )
    }

    func test_LHMapWorkspace_present() throws {
        try assertContract(
            file: "LHMapWorkspace.swift",
            symbolDeclaration: "public struct LHMapWorkspace"
        )
    }

    func test_LHMapFloatingChrome_present_andDeclaresHitRegion() throws {
        try assertContract(
            file: "LHMapFloatingChrome.swift",
            symbolDeclaration: "public struct LHMapFloatingChrome"
        )
        let source = try read("LHMapFloatingChrome.swift")
        XCTAssertTrue(source.contains("minimumHitRegion"))
        XCTAssertTrue(source.contains("44"),
                      "Floating chrome must encode the 44pt HIG hit region.")
    }

    func test_LHMapMetricCard_present() throws {
        try assertContract(
            file: "LHMapMetricCard.swift",
            symbolDeclaration: "public struct LHMapMetricCard"
        )
    }

    // MARK: - Glass dashboard + page scaffolds

    func test_LHGlassBottomSheetDashboard_present_andExposesDetents() throws {
        try assertContract(
            file: "LHGlassBottomSheetDashboard.swift",
            symbolDeclaration: "public struct LHGlassBottomSheetDashboard"
        )
        let source = try read("LHGlassBottomSheetDashboard.swift")
        XCTAssertTrue(source.contains("public enum LHSheetDetent"))
        XCTAssertTrue(source.contains("public struct LHSheetDetents"))
        XCTAssertTrue(source.contains("static let portrait"))
        XCTAssertTrue(source.contains("static let landscape"))
        XCTAssertTrue(source.contains("static let compactPortrait"))
    }

    func test_LHGlassPageScaffold_present() throws {
        try assertContract(
            file: "LHGlassPageScaffold.swift",
            symbolDeclaration: "public struct LHGlassPageScaffold"
        )
    }

    func test_LHGlassSectionCard_present() throws {
        try assertContract(
            file: "LHGlassSectionCard.swift",
            symbolDeclaration: "public struct LHGlassSectionCard"
        )
    }

    // MARK: - Phase A boundary

    func test_phaseA_doesNotMigrateExistingScreens() throws {
        // Phase A introduces shared components but does NOT swap them into
        // production screens. This guard asserts the canonical screens still
        // reference their pre-migration entry points.
        guard let root = sourcesDirectory() else {
            throw XCTSkip("Sources/ tree not reachable.")
        }
        let liveSource = try String(
            contentsOf: root.appendingPathComponent("AppLiveTrackingView.swift"),
            encoding: .utf8
        )
        // Until Phase B mounts the new scaffolds, the live screen must NOT
        // already reference them. If you are deliberately migrating Live,
        // update this test in the same PR.
        XCTAssertFalse(
            liveSource.contains("LHMapFirstPageScaffold"),
            "AppLiveTrackingView must not mount LHMapFirstPageScaffold in Phase A."
        )
        XCTAssertFalse(
            liveSource.contains("LHGlassBottomSheetDashboard"),
            "AppLiveTrackingView must not mount LHGlassBottomSheetDashboard in Phase A."
        )
    }
}
