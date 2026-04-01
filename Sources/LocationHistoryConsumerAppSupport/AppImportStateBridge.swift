import Foundation

public enum AppImportStateBridge {
    @discardableResult
    public static func rememberImportedFile(
        _ url: URL,
        userDefaults: UserDefaults = .standard
    ) -> RecentFileEntry? {
        ImportBookmarkStore.save(url: url, userDefaults: userDefaults)
        return RecentFilesStore.add(url: url, userDefaults: userDefaults)
    }

    public static func restoreLastImportIfEnabled(
        autoRestoreEnabled: Bool,
        userDefaults: UserDefaults = .standard
    ) -> URL? {
        guard autoRestoreEnabled else {
            return nil
        }
        return ImportBookmarkStore.restore(userDefaults: userDefaults)
    }
}
