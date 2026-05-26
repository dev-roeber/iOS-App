import XCTest

final class LGRecordButtonSourceTests: XCTestCase {
    func testRecordButtonUsesNativeGlassMorphingApis() throws {
        let source = try sourceFile("Sources/LocationHistoryConsumerAppSupport/LGRecordButton.swift")

        XCTAssertTrue(source.contains("GlassEffectContainer(spacing: 24)"))
        XCTAssertTrue(source.contains(".glassEffectID(\"left\""))
        XCTAssertTrue(source.contains(".glassEffectID(\"main\""))
        XCTAssertTrue(source.contains(".glassEffectID(\"right\""))
        XCTAssertTrue(source.contains(".buttonStyle(.glassProminent)"))
        XCTAssertTrue(source.contains(".buttonStyle(.glass)"))
    }

    func testRecordButtonPublicStateHasExpectedCases() throws {
        let source = try sourceFile("Sources/LocationHistoryConsumerAppSupport/LGRecordButton.swift")

        XCTAssertTrue(source.contains("public enum LGRecordState"))
        XCTAssertTrue(source.contains("case ready"))
        XCTAssertTrue(source.contains("case recording"))
        XCTAssertTrue(source.contains("case paused"))
    }

    func testLiveTrackingViewUsesRecordButtonBehindAvailabilityGate() throws {
        let source = try sourceFile("Sources/LocationHistoryConsumerAppSupport/AppLiveTrackingView.swift")

        XCTAssertTrue(source.contains("if #available(iOS 26.0, *)"))
        XCTAssertTrue(source.contains("LGRecordButton("))
        XCTAssertTrue(source.contains("LHLiveBottomBar("))
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
