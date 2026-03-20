import Foundation
import LocationHistoryConsumerAppSupport

/// Loads bundled demo fixtures and imported files for use in previews and tests.
public enum DemoDataLoader {
    public static let defaultFixtureName = AppContentLoader.defaultDemoFixtureName

    public static func loadDefaultContent() throws -> AppSessionContent {
        try loadContent(named: defaultFixtureName)
    }

    public static func loadContent(named name: String) throws -> AppSessionContent {
        try AppContentLoader.loadFixtureContent(
            named: name,
            from: Bundle.module,
            source: .demoFixture(name: name)
        )
    }

    public static func loadImportedContent(from url: URL) async throws -> AppSessionContent {
        try await AppContentLoader.loadImportedContent(from: url)
    }

    public static func fixtureURL(named name: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw AppContentLoaderError.fixtureNotFound(name)
        }
        return url
    }
}
