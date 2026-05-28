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

    // MARK: - Phase B-2 boundary: Live + DayDetail migrated, the others not yet

    func test_phaseB1_liveMountsTheNewScaffold() throws {
        // Phase B-1 must remain migrated. Regression guard.
        guard let root = sourcesDirectory() else {
            throw XCTSkip("Sources/ tree not reachable.")
        }
        let liveSource = try String(
            contentsOf: root.appendingPathComponent("AppLiveTrackingView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            liveSource.contains("LHMapFirstPageScaffold"),
            "AppLiveTrackingView must keep LHMapFirstPageScaffold from Phase B-1."
        )
        XCTAssertTrue(liveSource.contains("LHMapFloatingChrome"))
        XCTAssertTrue(liveSource.contains("LHGlassBottomSheetDashboard"))
    }

    func test_phaseB5_exportMountsTheNewScaffold() throws {
        // Phase B-5 migrates AppExportView heroEnabled-Pfad onto the shared
        // scaffold. LHMapFloatingChrome is NOT required — the existing
        // exportHeroMap (AppExportMultiLayerHero + AppExportPreviewMapView)
        // already overlays MapLayerMenu and layer toggles; a second
        // LHMapFloatingChrome would double the affordances (documented
        // exception, mirrors Insights B-3 and Map-Tab B-4).
        guard let root = sourcesDirectory() else {
            throw XCTSkip("Sources/ tree not reachable.")
        }
        let source = try String(
            contentsOf: root.appendingPathComponent("AppExportView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            source.contains("LHMapFirstPageScaffold"),
            "AppExportView must mount LHMapFirstPageScaffold in Phase B-5."
        )
        XCTAssertTrue(
            source.contains("LHGlassBottomSheetDashboard"),
            "AppExportView must mount LHGlassBottomSheetDashboard in Phase B-5."
        )
    }

    func test_phaseB4_mapTabHeroMountsTheNewScaffold() throws {
        // Phase B-4 migrates the Map-Tab Hero inside LGTabContainerView onto
        // the shared scaffold. LHMapFloatingChrome is NOT required —
        // `AppOverviewTracksMapView` already overlays MapLayerMenu + badges;
        // a second LHMapFloatingChrome would double the affordances
        // (documented exception, mirrors the Insights B-3 treatment).
        guard let root = sourcesDirectory() else {
            throw XCTSkip("Sources/ tree not reachable.")
        }
        let source = try String(
            contentsOf: root.appendingPathComponent("LGTabContainerView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            source.contains("LHMapFirstPageScaffold"),
            "LGTabContainerView.mapTab must mount LHMapFirstPageScaffold in Phase B-4."
        )
        XCTAssertTrue(
            source.contains("LHGlassBottomSheetDashboard"),
            "LGTabContainerView.mapTab must mount LHGlassBottomSheetDashboard in Phase B-4."
        )
    }

    func test_phaseB3_insightsMountsTheNewScaffold() throws {
        // Phase B-3 migrates AppInsightsContentView onto the shared scaffold
        // for the heroEnabled iOS-26 path. LHMapFloatingChrome is NOT
        // required here — `insightsHeroMap` already encapsulates its own
        // layer-panel + control-stack overlays via LHCollapsibleMapHeader
        // (documented exception in CHANGELOG and migration plan).
        guard let root = sourcesDirectory() else {
            throw XCTSkip("Sources/ tree not reachable.")
        }
        let source = try String(
            contentsOf: root.appendingPathComponent("AppInsightsContentView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            source.contains("LHMapFirstPageScaffold"),
            "AppInsightsContentView must mount LHMapFirstPageScaffold in Phase B-3."
        )
        XCTAssertTrue(
            source.contains("LHGlassBottomSheetDashboard"),
            "AppInsightsContentView must mount LHGlassBottomSheetDashboard in Phase B-3."
        )
    }

    func test_phaseB2_dayDetailMountsTheNewScaffold() throws {
        // Phase B-2 migrates AppDayDetailView onto the shared scaffold.
        guard let root = sourcesDirectory() else {
            throw XCTSkip("Sources/ tree not reachable.")
        }
        let source = try String(
            contentsOf: root.appendingPathComponent("AppDayDetailView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            source.contains("LHMapFirstPageScaffold"),
            "AppDayDetailView must mount LHMapFirstPageScaffold in Phase B-2."
        )
        XCTAssertTrue(
            source.contains("LHMapFloatingChrome"),
            "AppDayDetailView must mount LHMapFloatingChrome in Phase B-2."
        )
        XCTAssertTrue(
            source.contains("LHGlassBottomSheetDashboard"),
            "AppDayDetailView must mount LHGlassBottomSheetDashboard in Phase B-2."
        )
    }

    func test_phaseB5_remainingMapScreensNotYetMigrated() throws {
        // Heatmap and Editor remain on their pre-migration compositions;
        // update each entry in the corresponding sub-train PR.
        guard let root = sourcesDirectory() else {
            throw XCTSkip("Sources/ tree not reachable.")
        }
        let candidates = [
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

    func test_noMapContentBuilderRegression() throws {
        // After the Phase-A LHMapWorkspace hotfix (Build 288), the only
        // generic parameter constrained to `MapContent` lives in
        // LHMapWorkspace.swift with `@MapContentBuilder`. A regression
        // would re-introduce `<MapContent: View>` or `@ViewBuilder` next
        // to a MapKit `Map { ... }` builder elsewhere in the new
        // components.
        guard let root = sourcesDirectory() else {
            throw XCTSkip("Sources/ tree not reachable.")
        }
        let workspaceURL = root.appendingPathComponent("LHMapWorkspace.swift")
        let source = try String(contentsOf: workspaceURL, encoding: .utf8)
        XCTAssertTrue(
            source.contains("Content: MapContent"),
            "LHMapWorkspace must constrain its generic to the MapKit `MapContent` protocol."
        )
        XCTAssertTrue(
            source.contains("@MapContentBuilder"),
            "LHMapWorkspace must use `@MapContentBuilder` for its map closure."
        )
        XCTAssertFalse(
            source.contains("MapContent: View"),
            "LHMapWorkspace generic must NOT be constrained to View again — Build 288 regression."
        )
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
