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

    // MARK: - Phase B-1 boundary: Live migrated, the others not yet

    func test_phaseB1_liveMountsTheNewScaffold() throws {
        // Phase B-1 migrates the Live screen onto the shared scaffold while
        // every other map surface still uses its pre-migration composition.
        guard let root = sourcesDirectory() else {
            throw XCTSkip("Sources/ tree not reachable.")
        }
        let liveSource = try String(
            contentsOf: root.appendingPathComponent("AppLiveTrackingView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            liveSource.contains("LHMapFirstPageScaffold"),
            "AppLiveTrackingView must mount LHMapFirstPageScaffold in Phase B-1."
        )
        XCTAssertTrue(
            liveSource.contains("LHMapFloatingChrome"),
            "AppLiveTrackingView must mount LHMapFloatingChrome in Phase B-1."
        )
        XCTAssertTrue(
            liveSource.contains("LHGlassBottomSheetDashboard"),
            "AppLiveTrackingView must mount LHGlassBottomSheetDashboard in Phase B-1."
        )
    }

    func test_phaseB1_otherMapScreensNotYetMigrated() throws {
        // DayDetail / Insights / Map-Tab / Export / Heatmap / Editor remain
        // on their pre-migration compositions; update each entry in the
        // corresponding migration PR.
        guard let root = sourcesDirectory() else {
            throw XCTSkip("Sources/ tree not reachable.")
        }
        let candidates = [
            "AppDayDetailView.swift",
            "AppInsightsContentView.swift",
            "AppExportView.swift",
            "AppHeatmapView.swift",
            "AppRecordedTrackEditorView.swift"
        ]
        for relative in candidates {
            let url = root.appendingPathComponent(relative)
            guard let source = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            XCTAssertFalse(
                source.contains("LHMapFirstPageScaffold"),
                "\(relative) must not mount LHMapFirstPageScaffold before its Phase-B sub-train."
            )
        }
    }

    // MARK: - Xcode-Cloud regression guard

    func test_noAppLanguageScopeRegression() throws {
        // Linux skips files gated by `canImport(SwiftUI) && canImport(MapKit)`,
        // so a wrong type name there compiles under Linux but breaks Xcode
        // Cloud (see Phase-A hotfix in AppMapTabDashboardStrip.swift). This
        // guard fails fast if the wrong `AppLanguage` identifier (without
        // the `Preference` suffix) shows up again.
        guard let root = sourcesDirectory() else {
            throw XCTSkip("Sources/ tree not reachable.")
        }
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        )
        var offenders: [String] = []
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension == "swift" else { continue }
            guard let source = try? String(contentsOf: item, encoding: .utf8) else { continue }
            // Reject any literal use of `: AppLanguage` not followed by `Preference`.
            let pattern = ": AppLanguage"
            var searchRange = source.startIndex..<source.endIndex
            while let match = source.range(of: pattern, range: searchRange) {
                let afterEnd = match.upperBound
                if afterEnd < source.endIndex {
                    let nextChars = source[afterEnd..<source.index(afterEnd, offsetBy: min(10, source.distance(from: afterEnd, to: source.endIndex)))]
                    if !nextChars.hasPrefix("Preference") {
                        offenders.append(item.lastPathComponent)
                        break
                    }
                }
                searchRange = afterEnd..<source.endIndex
            }
        }
        XCTAssertTrue(
            offenders.isEmpty,
            "Stale `AppLanguage` (without `Preference` suffix) found in: \(offenders.joined(separator: ", "))"
        )
    }
}
