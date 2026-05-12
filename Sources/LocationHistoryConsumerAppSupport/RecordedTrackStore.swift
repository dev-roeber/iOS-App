import Foundation

public protocol RecordedTrackStoring {
    func loadTracks() throws -> [RecordedTrack]
    func saveTracks(_ tracks: [RecordedTrack]) throws
}

private struct RecordedTrackStorePayload: Codable {
    let schemaVersion: Int
    let tracks: [RecordedTrack]
}

public struct RecordedTrackFileStore: RecordedTrackStoring {
    private let fileManager: FileManager
    private let storageURL: URL

    public init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        if let baseDirectory {
            self.storageURL = baseDirectory
                .appendingPathComponent("RecordedTracks", isDirectory: true)
                .appendingPathComponent("recorded_live_tracks.json", isDirectory: false)
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.storageURL = appSupport
                .appendingPathComponent("LocationHistory2GPX", isDirectory: true)
                .appendingPathComponent("RecordedTracks", isDirectory: true)
                .appendingPathComponent("recorded_live_tracks.json", isDirectory: false)
        }
    }

    public func loadTracks() throws -> [RecordedTrack] {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(RecordedTrackStorePayload.self, from: data)
        return payload.tracks.sorted { $0.startedAt > $1.startedAt }
    }

    public func saveTracks(_ tracks: [RecordedTrack]) throws {
        let directory = storageURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload = RecordedTrackStorePayload(
            schemaVersion: 1,
            tracks: tracks.sorted { $0.startedAt > $1.startedAt }
        )
        let data = try encoder.encode(payload)
        try data.write(to: storageURL, options: .atomic)

        // Recorded live tracks contain user GPS coordinates. Mark the
        // directory and the file as excluded from iCloud / iTunes backup so
        // they don't silently leave the device through a generic backup —
        // matches the LocalTimelineStore SQLite roots which already do this
        // via LocalTimelineFileAttributes.markExcludedFromBackup. Failure is
        // intentionally swallowed: the write itself already succeeded and
        // backup-exclusion is a defence-in-depth flag, not a correctness
        // precondition.
        try? LocalTimelineFileAttributes.markExcludedFromBackupIfPresent(
            urls: [directory, storageURL]
        )
    }
}
