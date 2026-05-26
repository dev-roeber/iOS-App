import XCTest

final class LGTabContainerSourceTests: XCTestCase {
    // 1.1.0: LGTabContainerView wurde von wrapper/LH2GPXWrapper/ nach
    // Sources/LocationHistoryConsumerAppSupport/ verschoben (siehe Patch 05/11.A).
    private static let tabContainerRelativePath =
        "Sources/LocationHistoryConsumerAppSupport/LGTabContainerView.swift"

    func testTabContainerUsesNativeIOS26TabApis() throws {
        let source = try sourceFile(Self.tabContainerRelativePath)

        XCTAssertTrue(source.contains("Tab(\"Karte\", systemImage: \"map\", value: LGTab.map)"))
        // Prompt 03 LG_ROOT: Such-Tab entfernt (4 Tabs statt 5), Search
        // wandert in den Tage-Tab via lokalem .searchable(...) Modifier.
        XCTAssertFalse(
            source.contains("LGTab.search"),
            "Search tab should be removed (Prompt 03 LG_ROOT)"
        )
        XCTAssertTrue(source.contains(".searchable(text: $searchText"))
        XCTAssertTrue(source.contains(".tabBarMinimizeBehavior(.onScrollDown)"))
    }

    func testTabContainerShowsGlobalRecordingIndicatorWhileRecording() throws {
        // Phase 19.29: The bottom tabViewBottomAccessory pill was replaced by a
        // compact GlobalRecordingToolbarIndicator that lives in every tab's
        // toolbar (left of the actions menu) and is gated by
        // `liveLocation.isRecording`.
        let source = try sourceFile(Self.tabContainerRelativePath)

        XCTAssertTrue(source.contains("if liveLocation.isRecording"))
        XCTAssertTrue(source.contains("GlobalRecordingToolbarIndicator"))
        XCTAssertTrue(source.contains("currentDistanceMeters"))
    }

    func testContentViewRoutesToTabContainerOnIPhone() throws {
        let source = try sourceFile("wrapper/LH2GPXWrapper/ContentView.swift")

        // 1.1.0: Liquid-Glass ist Standard auf iPhone iOS 26. Der ContentView
        // routet anhand des Idioms + iOS-Verfügbarkeit, nicht mehr anhand
        // einer Preference.
        XCTAssertTrue(source.contains("UIDevice.current.userInterfaceIdiom == .phone"))
        XCTAssertTrue(source.contains("if #available(iOS 26.0, *)"))
        XCTAssertTrue(source.contains("LGTabContainerView("))
        XCTAssertTrue(source.contains("AppContentSplitView("))
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repoRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
