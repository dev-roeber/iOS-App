import XCTest

final class WeatherKitCapabilityConfigurationTests: XCTestCase {
    func testAppEntitlementsDeclareWeatherKit() throws {
        let source = try repoFile("wrapper/LH2GPXWrapper/LH2GPXWrapper.entitlements")
        XCTAssertTrue(source.contains("<key>com.apple.developer.weatherkit</key>"))
        XCTAssertTrue(source.contains("<true/>"))
    }

    func testWidgetEntitlementsDoNotDeclareWeatherKit() throws {
        let source = try repoFile("wrapper/LH2GPXWidget/LH2GPXWidget.entitlements")
        XCTAssertFalse(source.contains("com.apple.developer.weatherkit"))
    }

    func testAppAndWidgetTargetsUseSeparateEntitlementsFiles() throws {
        let source = try repoFile("wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj")
        XCTAssertEqual(source.components(separatedBy: "CODE_SIGN_ENTITLEMENTS = LH2GPXWrapper/LH2GPXWrapper.entitlements;").count - 1, 2)
        XCTAssertEqual(source.components(separatedBy: "CODE_SIGN_ENTITLEMENTS = LH2GPXWidget/LH2GPXWidget.entitlements;").count - 1, 2)
    }

    func testProjectDeclaresWeatherKitCapabilityForAppTargetOnly() throws {
        let source = try repoFile("wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj")
        let appTargetID = try nativeTargetID(named: "LH2GPXWrapper", in: source)
        let widgetTargetID = try nativeTargetID(named: "LH2GPXWidget", in: source)
        let appTarget = try targetAttributesBlock(appTargetID, in: source)
        let widgetTarget = try targetAttributesBlock(widgetTargetID, in: source)

        XCTAssertTrue(appTarget.contains("com.apple.WeatherKit"))
        XCTAssertFalse(widgetTarget.contains("com.apple.WeatherKit"))
    }

    private func repoFile(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func targetAttributesBlock(_ targetID: String, in source: String) throws -> String {
        guard let start = source.range(of: "\(targetID) = {\n\t\t\t\t\t\tCreatedOnToolsVersion") else {
            throw XCTSkip("Target attributes for \(targetID) not found")
        }
        let remainder = source[start.lowerBound...]
        guard let end = remainder.range(of: "\n\t\t\t\t\t};") else {
            throw XCTSkip("Target attributes block for \(targetID) is malformed")
        }
        return String(remainder[..<end.upperBound])
    }

    private func nativeTargetID(named name: String, in source: String) throws -> String {
        let marker = " /* \(name) */ = {\n\t\t\tisa = PBXNativeTarget;"
        guard let markerRange = source.range(of: marker) else {
            throw XCTSkip("PBXNativeTarget named \(name) not found")
        }

        let lineStart = source[..<markerRange.lowerBound].lastIndex(of: "\n")
            .map { source.index(after: $0) }
            ?? source.startIndex
        return String(source[lineStart..<markerRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
