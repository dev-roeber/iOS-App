import XCTest

final class WidgetRenderingModeTests: XCTestCase {
    func testHomeWidgetUsesRenderingModeAwareBackground() throws {
        let source = try homeWidgetSource()

        XCTAssertTrue(source.contains("@Environment(\\.widgetRenderingMode)"))
        XCTAssertTrue(source.contains("LH2GPXWidgetBackground()"))
        XCTAssertTrue(source.contains("case .fullColor:"))
        XCTAssertTrue(source.contains("case .accented, .vibrant:"))
        XCTAssertTrue(source.contains("Color.clear"))
    }

    func testHomeWidgetPreservesKindAndDataLoading() throws {
        let source = try homeWidgetSource()

        XCTAssertTrue(source.contains("let kind: String = \"LH2GPXHomeWidget\""))
        XCTAssertTrue(source.contains("WidgetDataStore.loadLastRecording()"))
        XCTAssertTrue(source.contains("WidgetDataStore.loadWeeklyStats()"))
    }

    func testHomeWidgetMetricFontsUseMonospacedDigits() throws {
        let source = try homeWidgetSource()

        XCTAssertGreaterThanOrEqual(source.components(separatedBy: ".monospacedDigit()").count - 1, 3)
        XCTAssertTrue(source.contains(".title2.weight(.bold).monospacedDigit()"))
        XCTAssertTrue(source.contains(".title3.weight(.bold).monospacedDigit()"))
    }

    private func homeWidgetSource() throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot
            .appendingPathComponent("wrapper/LH2GPXWidget/LH2GPXHomeWidget.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
