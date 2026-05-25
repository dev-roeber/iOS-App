import Foundation
#if canImport(OSLog)
import OSLog
#endif
#if canImport(CloudKit)
import CloudKit
#endif

public enum ICloudPrivateDatabaseReachability: String, Codable, Sendable, Equatable {
    case notChecked
    case reachable
    case unavailable
    case failed
}

/// Which stage of the CloudKit health probe failed first. Lets the UI
/// pinpoint whether the AccountStatus check, the `modifyRecords(saving:)`
/// write, the `records(for:)` read or the deleting write was the actual
/// failure rather than blanketing everything as „all three failed".
public enum ICloudHealthProbeStage: String, Codable, Sendable, Equatable {
    case accountStatus
    case write
    case read
    case delete
}

public struct ICloudHealthProbeResult: Codable, Sendable, Equatable {
    public var checkedAt: Date
    public var writeSucceeded: Bool
    public var readSucceeded: Bool
    public var deleteSucceeded: Bool
    public var durationSeconds: TimeInterval
    public var errorCode: String?
    public var errorMessage: String?
    /// Phase D.2: stage at which the probe stopped (nil = all stages
    /// completed successfully).
    public var errorStage: ICloudHealthProbeStage?
    /// Apple `CKError.Code` symbol name (e.g. „permissionFailure") when
    /// the failure was a CloudKit error. Always safe for `.public` logging.
    public var ckErrorCodeName: String?
    /// Honors `CKErrorRetryAfterKey` for rate-limited / service-unavailable
    /// failures so the UI can show a sensible „try again in X s" hint.
    public var retryAfterSeconds: Double?

    public init(
        checkedAt: Date = Date(),
        writeSucceeded: Bool = false,
        readSucceeded: Bool = false,
        deleteSucceeded: Bool = false,
        durationSeconds: TimeInterval = 0,
        errorCode: String? = nil,
        errorMessage: String? = nil,
        errorStage: ICloudHealthProbeStage? = nil,
        ckErrorCodeName: String? = nil,
        retryAfterSeconds: Double? = nil
    ) {
        self.checkedAt = checkedAt
        self.writeSucceeded = writeSucceeded
        self.readSucceeded = readSucceeded
        self.deleteSucceeded = deleteSucceeded
        self.durationSeconds = durationSeconds
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.errorStage = errorStage
        self.ckErrorCodeName = ckErrorCodeName
        self.retryAfterSeconds = retryAfterSeconds
    }

    // MARK: - Codable (backward-compatible with pre-D.2 JSON)

    private enum CodingKeys: String, CodingKey {
        case checkedAt, writeSucceeded, readSucceeded, deleteSucceeded
        case durationSeconds, errorCode, errorMessage
        case errorStage, ckErrorCodeName, retryAfterSeconds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        checkedAt = try c.decode(Date.self, forKey: .checkedAt)
        writeSucceeded = try c.decode(Bool.self, forKey: .writeSucceeded)
        readSucceeded = try c.decode(Bool.self, forKey: .readSucceeded)
        deleteSucceeded = try c.decode(Bool.self, forKey: .deleteSucceeded)
        durationSeconds = try c.decode(TimeInterval.self, forKey: .durationSeconds)
        errorCode = try c.decodeIfPresent(String.self, forKey: .errorCode)
        errorMessage = try c.decodeIfPresent(String.self, forKey: .errorMessage)
        errorStage = try c.decodeIfPresent(ICloudHealthProbeStage.self, forKey: .errorStage)
        ckErrorCodeName = try c.decodeIfPresent(String.self, forKey: .ckErrorCodeName)
        retryAfterSeconds = try c.decodeIfPresent(Double.self, forKey: .retryAfterSeconds)
    }
}

/// Phase D.2 — maps a raw `CKError.Code` to a stable string name (for
/// logging) and a short German diagnostic hint (for the UI). Pure value
/// helper — works on any platform; the `CKError`-flavored convenience
/// initializer is gated by `#if canImport(CloudKit)` below.
public struct ICloudCKErrorMapping: Equatable, Sendable {
    public let codeName: String
    public let germanHint: String

    public init(codeName: String, germanHint: String) {
        self.codeName = codeName
        self.germanHint = germanHint
    }

    public static func mapping(forRawCode raw: Int) -> ICloudCKErrorMapping {
        switch raw {
        case 1:  return .init(codeName: "internalError",        germanHint: "Interner CloudKit-Fehler. Bitte später erneut versuchen.")
        case 2:  return .init(codeName: "partialFailure",       germanHint: "Teilweiser CloudKit-Fehler. Einzelne Records nicht verarbeitet.")
        case 3:  return .init(codeName: "networkUnavailable",   germanHint: "Netzwerk nicht verfügbar.")
        case 4:  return .init(codeName: "networkFailure",       germanHint: "Netzwerkfehler — Verbindung prüfen.")
        case 5:  return .init(codeName: "badContainer",         germanHint: "Container-ID stimmt nicht mit dem Entitlement überein.")
        case 6:  return .init(codeName: "serviceUnavailable",   germanHint: "CloudKit-Dienst vorübergehend nicht verfügbar.")
        case 7:  return .init(codeName: "requestRateLimited",   germanHint: "Rate-Limit aktiv — später erneut versuchen.")
        case 8:  return .init(codeName: "missingEntitlement",   germanHint: "iCloud-Entitlement fehlt im signierten Build.")
        case 9:  return .init(codeName: "notAuthenticated",     germanHint: "Bitte in den System-Einstellungen bei iCloud anmelden.")
        case 10: return .init(codeName: "permissionFailure",    germanHint: "Entitlement oder Container-Berechtigung prüfen.")
        case 11: return .init(codeName: "unknownItem",          germanHint: "Production-Schema im CloudKit-Dashboard deployen.")
        case 12: return .init(codeName: "invalidArguments",     germanHint: "CloudKit hat die Anfrage abgelehnt.")
        case 15: return .init(codeName: "serverRejectedRequest", germanHint: "Schema oder Container-Konfiguration prüfen.")
        case 25: return .init(codeName: "quotaExceeded",        germanHint: "iCloud-Speicher des Nutzers ist voll.")
        case 26: return .init(codeName: "zoneNotFound",         germanHint: "CloudKit-Zone nicht vorhanden.")
        case 27: return .init(codeName: "limitExceeded",        germanHint: "CloudKit-Limit überschritten.")
        default: return .init(codeName: "ckError\(raw)",        germanHint: "Unbekannter CloudKit-Fehler.")
        }
    }
}

public struct ICloudHealthStatus: Sendable, Equatable {
    public var accountStatus: CloudSyncAccountStatus
    public var privateDatabaseReachability: ICloudPrivateDatabaseReachability
    public var lastProbeResult: ICloudHealthProbeResult?

    public init(
        accountStatus: CloudSyncAccountStatus = .disabled,
        privateDatabaseReachability: ICloudPrivateDatabaseReachability = .notChecked,
        lastProbeResult: ICloudHealthProbeResult? = nil
    ) {
        self.accountStatus = accountStatus
        self.privateDatabaseReachability = privateDatabaseReachability
        self.lastProbeResult = lastProbeResult
    }

    public var userFacingStatusKey: String {
        switch accountStatus {
        case .disabled:
            return "iCloud-Sync ist deaktiviert."
        case .available:
            switch privateDatabaseReachability {
            case .reachable:
                return "Privater CloudKit-Bereich erreichbar"
            case .notChecked:
                return "iCloud angemeldet, CloudKit-Test ausstehend"
            case .unavailable:
                return "Offline oder Netzwerk nicht verfügbar"
            case .failed:
                return "CloudKit-Test fehlgeschlagen"
            }
        case .signedOut:
            return "Nicht bei iCloud angemeldet"
        case .restricted:
            return "iCloud ist auf diesem Gerät eingeschränkt"
        case .couldNotDetermine, .temporarilyUnavailable:
            return "iCloud-Status konnte nicht bestimmt werden"
        case .error:
            return "CloudKit-Test fehlgeschlagen"
        }
    }

    /// Phase D.2 — separates the iCloud account check from the
    /// private-database reachability so the top status card no longer
    /// looks green while the Health-Check section is red.
    public var accountSummary: String {
        switch accountStatus {
        case .disabled:           return "iCloud-Sync ist deaktiviert"
        case .available:          return "iCloud-Konto verfügbar"
        case .signedOut:          return "Nicht bei iCloud angemeldet"
        case .restricted:         return "iCloud ist auf diesem Gerät eingeschränkt"
        case .couldNotDetermine:  return "iCloud-Kontostatus unbekannt"
        case .temporarilyUnavailable: return "iCloud vorübergehend nicht erreichbar"
        case .error:              return "iCloud-Konto-Status: Fehler"
        }
    }

    public var privateDatabaseSummary: String {
        switch privateDatabaseReachability {
        case .reachable:    return "Privater CloudKit-Speicher erreichbar"
        case .notChecked:   return "CloudKit-Speicher noch nicht geprüft"
        case .unavailable:  return "CloudKit-Speicher nicht erreichbar"
        case .failed:       return "CloudKit-Speicher nicht schreibbar"
        }
    }

    /// `true` while the user-visible state is „green enough" for queueing
    /// new LiveTrack backups against CloudKit. The auto-backup pipeline
    /// uses this gate (in addition to the user preferences) so the UI
    /// cannot promise something the cloud cannot deliver.
    public var isOperational: Bool {
        accountStatus == .available && privateDatabaseReachability == .reachable
    }
}

@MainActor
public protocol ICloudHealthChecking: AnyObject {
    var status: ICloudHealthStatus { get }
    func runHealthCheck(isEnabled: Bool) async -> ICloudHealthStatus
}

@MainActor
public final class InMemoryICloudHealthCheckService: ICloudHealthChecking {
    public private(set) var status: ICloudHealthStatus
    private var scriptedResult: ICloudHealthStatus

    public init(scriptedResult: ICloudHealthStatus = .init(accountStatus: .available)) {
        self.scriptedResult = scriptedResult
        self.status = .init()
    }

    public func setScriptedResult(_ result: ICloudHealthStatus) {
        scriptedResult = result
    }

    public func runHealthCheck(isEnabled: Bool) async -> ICloudHealthStatus {
        guard isEnabled else {
            status = .init(accountStatus: .disabled)
            return status
        }
        status = scriptedResult
        return status
    }
}

public enum ICloudCloudHealthProbeSchema {
    public static let recordType = "LH2GPXCloudHealthProbe"
    public static let schemaVersion = 1

    public enum Field {
        public static let createdAt = "createdAt"
        public static let appBuild = "appBuild"
        public static let schemaVersion = "schemaVersion"
        public static let randomProbeID = "randomProbeID"
    }
}

public struct LiveTrackCloudBackupSettings: Codable, Sendable, Equatable {
    public var iCloudSyncEnabled: Bool
    public var liveTrackMetadataEnabled: Bool
    public var liveTrackPointBatchesEnabled: Bool
    public var appSettingsEnabled: Bool
    public var exportHintsEnabled: Bool
    public var automaticLiveTrackBackupEnabled: Bool
    public var allowCellular: Bool

    public init(
        iCloudSyncEnabled: Bool = false,
        liveTrackMetadataEnabled: Bool = false,
        liveTrackPointBatchesEnabled: Bool = false,
        appSettingsEnabled: Bool = false,
        exportHintsEnabled: Bool = false,
        automaticLiveTrackBackupEnabled: Bool = false,
        allowCellular: Bool = false
    ) {
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.liveTrackMetadataEnabled = liveTrackMetadataEnabled
        self.liveTrackPointBatchesEnabled = liveTrackPointBatchesEnabled
        self.appSettingsEnabled = appSettingsEnabled
        self.exportHintsEnabled = exportHintsEnabled
        self.automaticLiveTrackBackupEnabled = automaticLiveTrackBackupEnabled
        self.allowCellular = allowCellular
    }

    public var canQueueCompletedLiveTrack: Bool {
        iCloudSyncEnabled && liveTrackMetadataEnabled && automaticLiveTrackBackupEnabled
    }
}

public enum LiveTrackCloudNetworkInterface: Sendable, Equatable {
    case wifiOrWired
    case cellular
    case unknown
}

public enum LiveTrackCloudBackupPolicy {
    public static func allowsUpload(
        settings: LiveTrackCloudBackupSettings,
        networkInterface: LiveTrackCloudNetworkInterface
    ) -> Bool {
        guard settings.canQueueCompletedLiveTrack else { return false }
        if networkInterface == .cellular && !settings.allowCellular {
            return false
        }
        return true
    }
}

public struct LiveTrackCloudSummary: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var schemaVersion: Int
    public var localTrackIDHash: String
    public var title: String
    public var startedAt: Date
    public var endedAt: Date
    public var durationSeconds: TimeInterval
    public var distanceM: Double
    public var pointCount: Int
    public var hasPointBatches: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var estimatedPayloadBytes: Int

    public init(track: RecordedTrack, includePointBatches: Bool, now: Date = Date()) {
        self.id = track.id
        self.schemaVersion = LiveTrackCloudSchema.schemaVersion
        self.localTrackIDHash = LiveTrackCloudSchema.hashLocalTrackID(track.id)
        self.title = "LiveTrack \(track.dayKey)"
        self.startedAt = track.startedAt
        self.endedAt = track.endedAt
        self.durationSeconds = track.endedAt.timeIntervalSince(track.startedAt)
        self.distanceM = track.distanceM
        self.pointCount = track.points.count
        self.hasPointBatches = includePointBatches
        self.createdAt = now
        self.updatedAt = now
        self.estimatedPayloadBytes = LiveTrackCloudSchema.estimatedSummaryBytes(pointCount: track.points.count)
    }
}

public struct LiveTrackCloudPointPayload: Codable, Sendable, Equatable {
    public var latitude: Double
    public var longitude: Double
    public var timestamp: Date
    public var horizontalAccuracyM: Double
    public var altitudeM: Double?
    public var verticalAccuracyM: Double?

    public init(point: RecordedTrackPoint) {
        self.latitude = point.latitude
        self.longitude = point.longitude
        self.timestamp = point.timestamp
        self.horizontalAccuracyM = point.horizontalAccuracyM
        if LocationElevationFormatter.isValidAltitude(altitudeM: point.altitudeM, verticalAccuracyM: point.verticalAccuracyM) {
            self.altitudeM = point.altitudeM
            self.verticalAccuracyM = point.verticalAccuracyM
        } else {
            self.altitudeM = nil
            self.verticalAccuracyM = nil
        }
    }
}

public struct LiveTrackCloudPointBatch: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(localTrackIDHash)-\(batchIndex)" }
    public var schemaVersion: Int
    public var localTrackIDHash: String
    public var batchIndex: Int
    public var batchCount: Int
    public var pointCount: Int
    public var encodedPointsPayload: String
    public var estimatedPayloadBytes: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        localTrackIDHash: String,
        batchIndex: Int,
        batchCount: Int,
        payload: [LiveTrackCloudPointPayload],
        now: Date = Date()
    ) throws {
        self.schemaVersion = LiveTrackCloudSchema.schemaVersion
        self.localTrackIDHash = localTrackIDHash
        self.batchIndex = batchIndex
        self.batchCount = batchCount
        self.pointCount = payload.count
        let data = try JSONEncoder.liveTrackCloud.encode(payload)
        self.encodedPointsPayload = data.base64EncodedString()
        self.estimatedPayloadBytes = data.count
        self.createdAt = now
        self.updatedAt = now
    }
}

public struct LiveTrackCloudBackupEnvelope: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID { summary.id }
    public var summary: LiveTrackCloudSummary
    public var pointBatches: [LiveTrackCloudPointBatch]
    public var queuedAt: Date
    public var lastAttemptAt: Date?
    public var lastErrorMessage: String?

    public init(summary: LiveTrackCloudSummary, pointBatches: [LiveTrackCloudPointBatch], queuedAt: Date = Date()) {
        self.summary = summary
        self.pointBatches = pointBatches
        self.queuedAt = queuedAt
        self.lastAttemptAt = nil
        self.lastErrorMessage = nil
    }
}

public enum LiveTrackCloudSchema {
    public static let schemaVersion = 1
    public static let summaryRecordType = "LH2GPXLiveTrackSummary"
    public static let pointBatchRecordType = "LH2GPXLiveTrackPointBatch"
    public static let maxPointsPerBatch = 100

    public enum SummaryField {
        public static let schemaVersion = "schemaVersion"
        public static let localTrackIDHash = "localTrackIDHash"
        public static let title = "title"
        public static let startedAt = "startedAt"
        public static let endedAt = "endedAt"
        public static let durationSeconds = "durationSeconds"
        public static let distanceM = "distanceM"
        public static let pointCount = "pointCount"
        public static let hasPointBatches = "hasPointBatches"
        public static let createdAt = "createdAt"
        public static let updatedAt = "updatedAt"
        public static let estimatedPayloadBytes = "estimatedPayloadBytes"
    }

    public enum PointBatchField {
        public static let schemaVersion = "schemaVersion"
        public static let localTrackIDHash = "localTrackIDHash"
        public static let batchIndex = "batchIndex"
        public static let batchCount = "batchCount"
        public static let pointCount = "pointCount"
        public static let encodedPointsPayload = "encodedPointsPayload"
        public static let estimatedPayloadBytes = "estimatedPayloadBytes"
        public static let createdAt = "createdAt"
        public static let updatedAt = "updatedAt"
    }

    public static func hashLocalTrackID(_ id: UUID) -> String {
        String(id.uuidString.replacingOccurrences(of: "-", with: "").prefix(16))
    }

    public static func estimatedSummaryBytes(pointCount: Int) -> Int {
        256 + max(0, pointCount) / 10
    }

    public static func makeEnvelope(
        for track: RecordedTrack,
        includePointBatches: Bool,
        now: Date = Date()
    ) throws -> LiveTrackCloudBackupEnvelope {
        let summary = LiveTrackCloudSummary(track: track, includePointBatches: includePointBatches, now: now)
        guard includePointBatches else {
            return LiveTrackCloudBackupEnvelope(summary: summary, pointBatches: [], queuedAt: now)
        }
        let payload = track.points.map(LiveTrackCloudPointPayload.init(point:))
        let chunks = payload.chunked(into: maxPointsPerBatch)
        let batches = try chunks.enumerated().map { index, chunk in
            try LiveTrackCloudPointBatch(
                localTrackIDHash: summary.localTrackIDHash,
                batchIndex: index,
                batchCount: chunks.count,
                payload: chunk,
                now: now
            )
        }
        return LiveTrackCloudBackupEnvelope(summary: summary, pointBatches: batches, queuedAt: now)
    }
}

public struct ICloudStorageOverview: Codable, Sendable, Equatable {
    public var summaryCount: Int
    public var pointBatchCount: Int
    public var estimatedPointCount: Int
    public var estimatedStorageBytes: Int
    public var lastSuccessfulBackupAt: Date?
    public var lastFailedBackupAt: Date?
    public var lastCloudKitStatusCheckAt: Date?
    public var errorMessage: String?

    public init(
        summaryCount: Int = 0,
        pointBatchCount: Int = 0,
        estimatedPointCount: Int = 0,
        estimatedStorageBytes: Int = 0,
        lastSuccessfulBackupAt: Date? = nil,
        lastFailedBackupAt: Date? = nil,
        lastCloudKitStatusCheckAt: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.summaryCount = summaryCount
        self.pointBatchCount = pointBatchCount
        self.estimatedPointCount = estimatedPointCount
        self.estimatedStorageBytes = estimatedStorageBytes
        self.lastSuccessfulBackupAt = lastSuccessfulBackupAt
        self.lastFailedBackupAt = lastFailedBackupAt
        self.lastCloudKitStatusCheckAt = lastCloudKitStatusCheckAt
        self.errorMessage = errorMessage
    }

    public var emptyMessageKey: String {
        summaryCount == 0 && pointBatchCount == 0
            ? "Noch keine Daten in iCloud gesichert."
            : "Cloud-Datenübersicht aktualisiert."
    }
}

public protocol LiveTrackCloudBackupQueueStoring: AnyObject {
    func loadEnvelopes() -> [LiveTrackCloudBackupEnvelope]
    func saveEnvelopes(_ envelopes: [LiveTrackCloudBackupEnvelope])
}

public final class UserDefaultsLiveTrackCloudBackupQueueStore: LiveTrackCloudBackupQueueStoring {
    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "app.icloud.liveTrackBackup.queue"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func loadEnvelopes() -> [LiveTrackCloudBackupEnvelope] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder.liveTrackCloud.decode([LiveTrackCloudBackupEnvelope].self, from: data)
        else {
            return []
        }
        return decoded
    }

    public func saveEnvelopes(_ envelopes: [LiveTrackCloudBackupEnvelope]) {
        if envelopes.isEmpty {
            userDefaults.removeObject(forKey: key)
            return
        }
        if let data = try? JSONEncoder.liveTrackCloud.encode(envelopes) {
            userDefaults.set(data, forKey: key)
        }
    }
}

public final class InMemoryLiveTrackCloudBackupQueueStore: LiveTrackCloudBackupQueueStoring {
    public private(set) var envelopes: [LiveTrackCloudBackupEnvelope]

    public init(envelopes: [LiveTrackCloudBackupEnvelope] = []) {
        self.envelopes = envelopes
    }

    public func loadEnvelopes() -> [LiveTrackCloudBackupEnvelope] {
        envelopes
    }

    public func saveEnvelopes(_ envelopes: [LiveTrackCloudBackupEnvelope]) {
        self.envelopes = envelopes
    }
}

@MainActor
public protocol LiveTrackCloudBackupCoordinator: AnyObject {
    var overview: ICloudStorageOverview { get }
    var pendingCount: Int { get }
    func handleCompletedLiveTrack(_ track: RecordedTrack)
    func retryPendingBackups() async
    func refreshOverview() async -> ICloudStorageOverview
    func deleteCloudData() async throws
}

@MainActor
public final class LiveTrackCloudBackupService: LiveTrackCloudBackupCoordinator {
    public private(set) var overview: ICloudStorageOverview
    public var pendingCount: Int { queueStore.loadEnvelopes().count }

    private let settingsProvider: () -> LiveTrackCloudBackupSettings
    private let queueStore: LiveTrackCloudBackupQueueStoring
    private let uploader: LiveTrackCloudBackupUploading
    private let networkInterfaceProvider: () -> LiveTrackCloudNetworkInterface
    /// Phase D.2 — pluggable Health-Gate. Returns `true` while CloudKit is
    /// known to be operational; queued uploads pause when the gate is shut.
    /// Default returns `true` so legacy call-sites without a health probe
    /// continue to behave as before.
    private let healthGate: () -> Bool
    private var uploadedTrackIDs: Set<UUID>

    public init(
        settingsProvider: @escaping () -> LiveTrackCloudBackupSettings,
        queueStore: LiveTrackCloudBackupQueueStoring = UserDefaultsLiveTrackCloudBackupQueueStore(),
        uploader: LiveTrackCloudBackupUploading = NoopLiveTrackCloudBackupUploader(),
        networkInterfaceProvider: @escaping () -> LiveTrackCloudNetworkInterface = { .unknown },
        healthGate: @escaping () -> Bool = { true },
        overview: ICloudStorageOverview = .init()
    ) {
        self.settingsProvider = settingsProvider
        self.queueStore = queueStore
        self.uploader = uploader
        self.networkInterfaceProvider = networkInterfaceProvider
        self.healthGate = healthGate
        self.overview = overview
        self.uploadedTrackIDs = Set(queueStore.loadEnvelopes().map(\.summary.id))
    }

    public func handleCompletedLiveTrack(_ track: RecordedTrack) {
        let settings = settingsProvider()
        guard settings.canQueueCompletedLiveTrack else { return }
        var queued = queueStore.loadEnvelopes()
        guard !uploadedTrackIDs.contains(track.id),
              !queued.contains(where: { $0.summary.id == track.id })
        else {
            return
        }
        guard let envelope = try? LiveTrackCloudSchema.makeEnvelope(
            for: track,
            includePointBatches: settings.liveTrackPointBatchesEnabled
        ) else {
            return
        }
        queued.append(envelope)
        queueStore.saveEnvelopes(queued)
        Task { @MainActor [weak self] in
            await self?.retryPendingBackups()
        }
    }

    public func retryPendingBackups() async {
        let settings = settingsProvider()
        guard LiveTrackCloudBackupPolicy.allowsUpload(
            settings: settings,
            networkInterface: networkInterfaceProvider()
        ) else {
            return
        }
        // Phase D.2 — health-gate: do not retry against a known-broken
        // CloudKit endpoint. Pending envelopes stay in the outbox so they
        // automatically resume after the next successful health probe.
        guard healthGate() else {
            return
        }

        var remaining: [LiveTrackCloudBackupEnvelope] = []
        for var envelope in queueStore.loadEnvelopes() {
            do {
                envelope.lastAttemptAt = Date()
                try await uploader.upload(envelope)
                uploadedTrackIDs.insert(envelope.summary.id)
                overview.lastSuccessfulBackupAt = Date()
            } catch {
                envelope.lastErrorMessage = "CloudKit-Sicherung fehlgeschlagen."
                overview.lastFailedBackupAt = Date()
                remaining.append(envelope)
            }
        }
        queueStore.saveEnvelopes(remaining)
    }

    public func refreshOverview() async -> ICloudStorageOverview {
        do {
            overview = try await uploader.fetchOverview()
        } catch {
            overview.errorMessage = "Cloud-Datenübersicht konnte nicht aktualisiert werden."
        }
        return overview
    }

    public func deleteCloudData() async throws {
        try await uploader.deleteCloudData()
        overview = .init()
    }
}

public protocol LiveTrackCloudBackupUploading: Sendable {
    func upload(_ envelope: LiveTrackCloudBackupEnvelope) async throws
    func fetchOverview() async throws -> ICloudStorageOverview
    func deleteCloudData() async throws
}

public struct NoopLiveTrackCloudBackupUploader: LiveTrackCloudBackupUploading {
    public init() {}
    public func upload(_ envelope: LiveTrackCloudBackupEnvelope) async throws {}
    public func fetchOverview() async throws -> ICloudStorageOverview { .init() }
    public func deleteCloudData() async throws {}
}

@MainActor
public enum LiveTrackCloudBackupFactory {
    public static func makeProductionService(
        settingsProvider: @escaping () -> LiveTrackCloudBackupSettings,
        healthGate: @escaping () -> Bool = { true }
    ) -> LiveTrackCloudBackupService {
        #if canImport(CloudKit)
        return LiveTrackCloudBackupService(
            settingsProvider: settingsProvider,
            uploader: CloudKitLiveTrackCloudBackupUploader(),
            healthGate: healthGate
        )
        #else
        return LiveTrackCloudBackupService(
            settingsProvider: settingsProvider,
            healthGate: healthGate
        )
        #endif
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

private extension JSONEncoder {
    static var liveTrackCloud: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var liveTrackCloud: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

#if canImport(CloudKit)
@MainActor
public final class CloudKitICloudHealthCheckService: ICloudHealthChecking {
    public private(set) var status: ICloudHealthStatus

    private let container: CKContainer
    private let appBuildProvider: () -> String
    #if canImport(OSLog)
    private let logger = Logger(subsystem: "de.roeber.LH2GPXWrapper", category: "iCloud")
    #endif

    public init(
        containerIdentifier: String = CloudKitCloudSyncService.defaultContainerIdentifier,
        appBuildProvider: @escaping () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        }
    ) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.appBuildProvider = appBuildProvider
        self.status = .init()
    }

    public func runHealthCheck(isEnabled: Bool) async -> ICloudHealthStatus {
        guard isEnabled else {
            status = .init(accountStatus: .disabled)
            return status
        }
        let start = Date()

        // MARK: Stage 1 — Account status
        let mapped: CloudSyncAccountStatus
        do {
            let account = try await container.accountStatus()
            mapped = CloudKitCloudSyncService.map(account)
        } catch {
            status = .init(
                accountStatus: .couldNotDetermine,
                privateDatabaseReachability: .notChecked,
                lastProbeResult: Self.makeFailureResult(
                    stage: .accountStatus,
                    error: error,
                    durationSeconds: Date().timeIntervalSince(start)
                )
            )
            #if canImport(OSLog)
            logger.error("CloudKit accountStatus failed: code=\(self.probeCodeName(for: error), privacy: .public)")
            #endif
            return status
        }
        guard mapped == .available else {
            status = .init(accountStatus: mapped, privateDatabaseReachability: .notChecked)
            return status
        }

        // MARK: Stage 2 — Write probe
        let recordID = CKRecord.ID(recordName: "probe-\(UUID().uuidString)")
        let record = CKRecord(recordType: ICloudCloudHealthProbeSchema.recordType, recordID: recordID)
        record[ICloudCloudHealthProbeSchema.Field.createdAt] = Date() as CKRecordValue
        record[ICloudCloudHealthProbeSchema.Field.appBuild] = appBuildProvider() as CKRecordValue
        record[ICloudCloudHealthProbeSchema.Field.schemaVersion] = ICloudCloudHealthProbeSchema.schemaVersion as CKRecordValue
        record[ICloudCloudHealthProbeSchema.Field.randomProbeID] = UUID().uuidString as CKRecordValue

        do {
            _ = try await container.privateCloudDatabase.modifyRecords(
                saving: [record],
                deleting: [],
                savePolicy: .changedKeys,
                atomically: true
            )
        } catch {
            status = .init(
                accountStatus: .available,
                privateDatabaseReachability: .failed,
                lastProbeResult: Self.makeFailureResult(
                    stage: .write,
                    error: error,
                    durationSeconds: Date().timeIntervalSince(start)
                )
            )
            #if canImport(OSLog)
            logger.error("CloudKit write probe failed: code=\(self.probeCodeName(for: error), privacy: .public)")
            #endif
            return status
        }

        // MARK: Stage 3 — Read probe
        do {
            let fetched = try await container.privateCloudDatabase.records(for: [recordID])
            if case .failure(let readError) = fetched[recordID] {
                throw readError
            }
        } catch {
            status = .init(
                accountStatus: .available,
                privateDatabaseReachability: .failed,
                lastProbeResult: Self.makeFailureResult(
                    stage: .read,
                    error: error,
                    durationSeconds: Date().timeIntervalSince(start),
                    writeSucceeded: true
                )
            )
            #if canImport(OSLog)
            logger.error("CloudKit read probe failed: code=\(self.probeCodeName(for: error), privacy: .public)")
            #endif
            return status
        }

        // MARK: Stage 4 — Delete probe
        do {
            _ = try await container.privateCloudDatabase.modifyRecords(
                saving: [],
                deleting: [recordID],
                savePolicy: .changedKeys,
                atomically: true
            )
        } catch {
            status = .init(
                accountStatus: .available,
                privateDatabaseReachability: .failed,
                lastProbeResult: Self.makeFailureResult(
                    stage: .delete,
                    error: error,
                    durationSeconds: Date().timeIntervalSince(start),
                    writeSucceeded: true,
                    readSucceeded: true
                )
            )
            #if canImport(OSLog)
            logger.error("CloudKit delete probe failed: code=\(self.probeCodeName(for: error), privacy: .public)")
            #endif
            return status
        }

        let probe = ICloudHealthProbeResult(
            checkedAt: Date(),
            writeSucceeded: true,
            readSucceeded: true,
            deleteSucceeded: true,
            durationSeconds: Date().timeIntervalSince(start)
        )
        status = .init(
            accountStatus: .available,
            privateDatabaseReachability: .reachable,
            lastProbeResult: probe
        )
        #if canImport(OSLog)
        logger.info("CloudKit health probe succeeded in \(probe.durationSeconds, privacy: .public) seconds")
        #endif
        return status
    }

    private static func makeFailureResult(
        stage: ICloudHealthProbeStage,
        error: Error,
        durationSeconds: TimeInterval,
        writeSucceeded: Bool = false,
        readSucceeded: Bool = false
    ) -> ICloudHealthProbeResult {
        let ckError = error as? CKError
        let mapping = ckError.map { ICloudCKErrorMapping.mapping(forRawCode: $0.code.rawValue) }
        let retryAfter: Double? = {
            guard let info = (error as NSError?)?.userInfo else { return nil }
            return (info["CKErrorRetryAfterKey"] as? NSNumber)?.doubleValue
        }()
        return ICloudHealthProbeResult(
            checkedAt: Date(),
            writeSucceeded: writeSucceeded,
            readSucceeded: readSucceeded,
            deleteSucceeded: false,
            durationSeconds: durationSeconds,
            errorCode: ckError.map { "\($0.code.rawValue)" },
            errorMessage: mapping?.germanHint ?? "Unbekannter Fehler.",
            errorStage: stage,
            ckErrorCodeName: mapping?.codeName,
            retryAfterSeconds: retryAfter
        )
    }

    private func probeCodeName(for error: Error) -> String {
        if let ck = error as? CKError {
            return ICloudCKErrorMapping.mapping(forRawCode: ck.code.rawValue).codeName
        }
        return "non-ckerror"
    }
}

public struct CloudKitLiveTrackCloudBackupUploader: LiveTrackCloudBackupUploading {
    private let containerIdentifier: String

    public init(containerIdentifier: String = CloudKitCloudSyncService.defaultContainerIdentifier) {
        self.containerIdentifier = containerIdentifier
    }

    public func upload(_ envelope: LiveTrackCloudBackupEnvelope) async throws {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let records = [Self.makeSummaryRecord(envelope.summary)]
            + envelope.pointBatches.map(Self.makePointBatchRecord)
        _ = try await database.modifyRecords(
            saving: records,
            deleting: [],
            savePolicy: .changedKeys,
            atomically: true
        )
    }

    public func fetchOverview() async throws -> ICloudStorageOverview {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let summaryQuery = CKQuery(recordType: LiveTrackCloudSchema.summaryRecordType, predicate: NSPredicate(value: true))
        let batchQuery = CKQuery(recordType: LiveTrackCloudSchema.pointBatchRecordType, predicate: NSPredicate(value: true))
        let summaries = try await database.records(matching: summaryQuery, resultsLimit: 200).matchResults
        let batches = try await database.records(matching: batchQuery, resultsLimit: 200).matchResults
        var overview = ICloudStorageOverview()
        overview.summaryCount = summaries.count
        overview.pointBatchCount = batches.count
        overview.lastCloudKitStatusCheckAt = Date()
        for result in summaries {
            if case .success(let record) = result.1 {
                overview.estimatedPointCount += (record[LiveTrackCloudSchema.SummaryField.pointCount] as? Int)
                    ?? (record[LiveTrackCloudSchema.SummaryField.pointCount] as? NSNumber)?.intValue
                    ?? 0
                overview.estimatedStorageBytes += (record[LiveTrackCloudSchema.SummaryField.estimatedPayloadBytes] as? Int)
                    ?? (record[LiveTrackCloudSchema.SummaryField.estimatedPayloadBytes] as? NSNumber)?.intValue
                    ?? 0
            }
        }
        for result in batches {
            if case .success(let record) = result.1 {
                overview.estimatedStorageBytes += (record[LiveTrackCloudSchema.PointBatchField.estimatedPayloadBytes] as? Int)
                    ?? (record[LiveTrackCloudSchema.PointBatchField.estimatedPayloadBytes] as? NSNumber)?.intValue
                    ?? 0
            }
        }
        return overview
    }

    public func deleteCloudData() async throws {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let recordTypes = [
            ICloudCloudHealthProbeSchema.recordType,
            LiveTrackCloudSchema.summaryRecordType,
            LiveTrackCloudSchema.pointBatchRecordType,
        ]
        for recordType in recordTypes {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            let results = try await database.records(matching: query, resultsLimit: 200).matchResults
            for (recordID, result) in results {
                if case .success = result {
                    _ = try await database.modifyRecords(
                        saving: [],
                        deleting: [recordID],
                        savePolicy: .changedKeys,
                        atomically: true
                    )
                }
            }
        }
    }

    static func makeSummaryRecord(_ summary: LiveTrackCloudSummary) -> CKRecord {
        let record = CKRecord(
            recordType: LiveTrackCloudSchema.summaryRecordType,
            recordID: CKRecord.ID(recordName: "summary-\(summary.localTrackIDHash)")
        )
        record[LiveTrackCloudSchema.SummaryField.schemaVersion] = summary.schemaVersion as CKRecordValue
        record[LiveTrackCloudSchema.SummaryField.localTrackIDHash] = summary.localTrackIDHash as CKRecordValue
        record[LiveTrackCloudSchema.SummaryField.title] = summary.title as CKRecordValue
        record[LiveTrackCloudSchema.SummaryField.startedAt] = summary.startedAt as CKRecordValue
        record[LiveTrackCloudSchema.SummaryField.endedAt] = summary.endedAt as CKRecordValue
        record[LiveTrackCloudSchema.SummaryField.durationSeconds] = summary.durationSeconds as CKRecordValue
        record[LiveTrackCloudSchema.SummaryField.distanceM] = summary.distanceM as CKRecordValue
        record[LiveTrackCloudSchema.SummaryField.pointCount] = summary.pointCount as CKRecordValue
        record[LiveTrackCloudSchema.SummaryField.hasPointBatches] = summary.hasPointBatches as CKRecordValue
        record[LiveTrackCloudSchema.SummaryField.createdAt] = summary.createdAt as CKRecordValue
        record[LiveTrackCloudSchema.SummaryField.updatedAt] = summary.updatedAt as CKRecordValue
        record[LiveTrackCloudSchema.SummaryField.estimatedPayloadBytes] = summary.estimatedPayloadBytes as CKRecordValue
        return record
    }

    static func makePointBatchRecord(_ batch: LiveTrackCloudPointBatch) -> CKRecord {
        let record = CKRecord(
            recordType: LiveTrackCloudSchema.pointBatchRecordType,
            recordID: CKRecord.ID(recordName: "points-\(batch.localTrackIDHash)-\(batch.batchIndex)")
        )
        record[LiveTrackCloudSchema.PointBatchField.schemaVersion] = batch.schemaVersion as CKRecordValue
        record[LiveTrackCloudSchema.PointBatchField.localTrackIDHash] = batch.localTrackIDHash as CKRecordValue
        record[LiveTrackCloudSchema.PointBatchField.batchIndex] = batch.batchIndex as CKRecordValue
        record[LiveTrackCloudSchema.PointBatchField.batchCount] = batch.batchCount as CKRecordValue
        record[LiveTrackCloudSchema.PointBatchField.pointCount] = batch.pointCount as CKRecordValue
        record[LiveTrackCloudSchema.PointBatchField.encodedPointsPayload] = batch.encodedPointsPayload as CKRecordValue
        record[LiveTrackCloudSchema.PointBatchField.estimatedPayloadBytes] = batch.estimatedPayloadBytes as CKRecordValue
        record[LiveTrackCloudSchema.PointBatchField.createdAt] = batch.createdAt as CKRecordValue
        record[LiveTrackCloudSchema.PointBatchField.updatedAt] = batch.updatedAt as CKRecordValue
        return record
    }
}
#endif
