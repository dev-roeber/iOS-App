import XCTest
import LocationHistoryConsumerAppSupport

final class RecordedTrackStoreTests: XCTestCase {
    func testLoadReturnsEmptyWhenStoreFileIsMissing() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = RecordedTrackFileStore(baseDirectory: root)

        let tracks = try store.loadTracks()

        XCTAssertTrue(tracks.isEmpty)
    }

    func testSaveAndLoadRoundTripsTracks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = RecordedTrackFileStore(baseDirectory: root)
        let track = makeTrack()

        try store.saveTracks([track])
        let loadedTracks = try store.loadTracks()

        XCTAssertEqual(loadedTracks, [track])
    }

    func testStoreWritesToDedicatedRecordedTracksPath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = RecordedTrackFileStore(baseDirectory: root)

        try store.saveTracks([makeTrack()])

        let expectedFile = root
            .appendingPathComponent("RecordedTracks", isDirectory: true)
            .appendingPathComponent("recorded_live_tracks.json", isDirectory: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("app_export.json").path))
    }

    private func makeTrack() -> RecordedTrack {
        let start = Date(timeIntervalSince1970: 1_710_000_000)
        let end = start.addingTimeInterval(20)
        return RecordedTrack(
            startedAt: start,
            endedAt: end,
            dayKey: "2024-03-09",
            distanceM: 42,
            captureMode: .foregroundWhileInUse,
            points: [
                RecordedTrackPoint(
                    latitude: 52.52,
                    longitude: 13.40,
                    timestamp: start,
                    horizontalAccuracyM: 5
                ),
                RecordedTrackPoint(
                    latitude: 52.5202,
                    longitude: 13.4002,
                    timestamp: end,
                    horizontalAccuracyM: 5
                ),
            ]
        )
    }
}
