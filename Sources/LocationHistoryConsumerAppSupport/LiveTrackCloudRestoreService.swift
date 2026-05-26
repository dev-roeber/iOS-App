import Foundation
#if canImport(Combine)
import Combine
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Prompt 2 — koordiniert den Restore-Pfad für LiveTracks aus CloudKit.
///
/// Verantwortlichkeiten:
/// - Lädt verfügbare Envelopes über `LiveTrackCloudBackupCoordinator.fetchRestorableEnvelopes()`.
/// - Bietet einen Decode-Schritt `restore(_:)`, der einen Envelope in
///   einen `RecordedTrack` umwandelt und in den `RecordedTrackStoring`
///   schreibt (dedupliziert per `localTrackIDHash`-Hash der bereits
///   vorhandenen Tracks).
/// - Hält einen `actionState` (idle/loading/restoring) + Erfolgs-/Fehler-
///   Meldung analog zum Phase-D.4 Muster.

public enum LiveTrackRestoreActionState: String, Sendable {
    case idle
    case loading
    case uploading
    case restoring
}

public struct LiveTrackRestoreOutcome: Equatable, Sendable {
    public let envelopeID: UUID
    public let restoredTrackID: UUID
    public let pointCount: Int
}

#if canImport(Combine)
@MainActor
public final class LiveTrackCloudRestoreService: ObservableObject {
    @Published public private(set) var availableEnvelopes: [LiveTrackCloudBackupEnvelope] = []
    @Published public private(set) var actionState: LiveTrackRestoreActionState = .idle
    @Published public var actionMessage: String?
    @Published public var actionFailed: Bool = false

    private let coordinator: LiveTrackCloudBackupCoordinator
    private let trackStore: RecordedTrackStoring
    private let now: () -> Date
    private let userDefaults: UserDefaults
    private let restoredHashesKey: String
    private var restoredCloudHashes: Set<String> = []

    public init(
        coordinator: LiveTrackCloudBackupCoordinator,
        trackStore: RecordedTrackStoring,
        now: @escaping () -> Date = Date.init,
        userDefaults: UserDefaults = .standard,
        restoredHashesKey: String = "app.icloud.liveTrackRestore.restoredCloudHashes"
    ) {
        self.coordinator = coordinator
        self.trackStore = trackStore
        self.now = now
        self.userDefaults = userDefaults
        self.restoredHashesKey = restoredHashesKey
        self.restoredCloudHashes = Set(userDefaults.stringArray(forKey: restoredHashesKey) ?? [])
    }

    public func loadAvailable() async {
        guard actionState == .idle else { return }
        actionState = .loading
        actionFailed = false
        actionMessage = nil
        do {
            availableEnvelopes = try await coordinator.fetchRestorableEnvelopes()
            actionMessage = "Cloud-LiveTracks geladen (\(availableEnvelopes.count))."
        } catch {
            actionFailed = true
            actionMessage = "Cloud-LiveTracks konnten nicht geladen werden: \(error.localizedDescription)"
        }
        actionState = .idle
    }

    public func uploadLatestLocalTrack(includePointBatches: Bool) async {
        guard actionState == .idle else { return }
        actionState = .uploading
        actionFailed = false
        actionMessage = nil
        defer { actionState = .idle }
        do {
            guard let latest = try trackStore.loadTracks().sorted(by: { $0.startedAt > $1.startedAt }).first else {
                actionMessage = "Kein lokaler LiveTrack zum Hochladen vorhanden."
                return
            }
            try await coordinator.uploadManually(latest, includePointBatches: includePointBatches)
            actionMessage = "LiveTrack-Upload abgeschlossen."
        } catch {
            actionFailed = true
            actionMessage = "LiveTrack-Upload fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    /// Restored den angegebenen Envelope. Bei bereits vorhandenem
    /// `localTrackIDHash` im lokalen Store wird der Restore übersprungen
    /// und die Meldung „Bereits vorhanden" gesetzt (Dedupe).
    public func restore(_ envelope: LiveTrackCloudBackupEnvelope) async -> LiveTrackRestoreOutcome? {
        guard actionState == .idle else { return nil }
        actionState = .restoring
        actionFailed = false
        actionMessage = nil
        defer { actionState = .idle }
        do {
            let existing = (try? trackStore.loadTracks()) ?? []
            let knownHashes = Set(existing.map { LiveTrackCloudSchema.hashLocalTrackID($0.id) })
            if knownHashes.contains(envelope.summary.localTrackIDHash)
                || restoredCloudHashes.contains(envelope.summary.localTrackIDHash) {
                actionMessage = "LiveTrack ist bereits lokal vorhanden — nichts zu tun."
                return nil
            }
            let track = try LiveTrackCloudSchema.decodeRecordedTrack(from: envelope)
            var merged = existing
            merged.append(track)
            try trackStore.saveTracks(merged)
            restoredCloudHashes.insert(envelope.summary.localTrackIDHash)
            userDefaults.set(Array(restoredCloudHashes).sorted(), forKey: restoredHashesKey)
            actionMessage = "LiveTrack mit \(track.points.count) Punkten wiederhergestellt."
            // Mirror LiveLocationFeatureModel.persistRecordedTracks /
            // updateWidgetData — after a successful CloudKit restore the
            // home-screen widget must see the new track too, otherwise its
            // weekly/monthly stats and last-recording card drift from truth.
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            return LiveTrackRestoreOutcome(
                envelopeID: envelope.id,
                restoredTrackID: track.id,
                pointCount: track.points.count
            )
        } catch {
            actionFailed = true
            actionMessage = "Restore fehlgeschlagen: \(error.localizedDescription)"
            return nil
        }
    }
}
#endif
