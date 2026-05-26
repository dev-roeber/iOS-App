import XCTest

final class LGTabContainerSourceTests: XCTestCase {
    func testTabContainerUsesNativeIOS26TabApis() throws {
        let source = try sourceFile("wrapper/LH2GPXWrapper/LGTabContainerView.swift")

        XCTAssertTrue(source.contains("Tab(\"Karte\", systemImage: \"map\", value: 0)"))
        XCTAssertTrue(source.contains("Tab(\"Suche\", systemImage: \"magnifyingglass\", value: 4, role: .search)"))
        XCTAssertTrue(source.contains(".searchable(text: $searchText"))
        XCTAssertTrue(source.contains(".tabBarMinimizeBehavior(.onScrollDown)"))
        XCTAssertTrue(source.contains(".tabViewBottomAccessory"))
    }

    func testTabContainerShowsLiveRecordingAccessoryOnlyWhileRecording() throws {
        let source = try sourceFile("wrapper/LH2GPXWrapper/LGTabContainerView.swift")

        XCTAssertTrue(source.contains("if liveLocation.isRecording"))
        XCTAssertTrue(source.contains("LiveRecordingAccessory"))
        XCTAssertTrue(source.contains(".symbolEffect(.pulse, options: .repeating, value: liveModel.isRecording)"))
        XCTAssertTrue(source.contains(".buttonStyle(.glass)"))
    }

    func testContentViewGatesTabContainerBehindPreference() throws {
        let source = try sourceFile("wrapper/LH2GPXWrapper/ContentView.swift")

        XCTAssertTrue(source.contains("preferences.useLiquidGlassTabContainer"))
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
