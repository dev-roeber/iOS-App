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

/// Phase D.3 — Linux-testable per-record validation for CloudKit
/// `modifyRecords` / `records(for:)` outcomes. The async APIs return a
/// `(saveResults: [ID: Result<…>], deleteResults: [ID: Result<…>])` even
/// when the outer `try await` succeeds — Apple-Doku is explicit that
/// individual records can fail server-side without the outer call
/// throwing. The wire-level success of the request is **not** the same
/// as „my record was actually persisted". Phase D.2 only checked the
/// outer throw, which is exactly why the health-probe screenshot showed
/// „Schreiben ✓ · Lesen CKError.unknownItem" — the write was lost
/// server-side, the subsequent read could never find the record, and we
/// mis-classified the stage. These helpers map raw per-record outcomes
/// to a single throwing assertion so the call-site can collapse the
/// dictionary into a clean do/catch.
public enum ICloudPerRecordValidationError: Error, Equatable {
    /// The outcome dictionary contained no entry for the expected record.
    case missingResult
    /// The per-record `Result` was `.failure(...)`. The wrapped value
    /// is the underlying `NSError`-bridgeable error; callers downcast to
    /// `CKError` for `code.rawValue` mapping.
    case recordFailed(localizedDescription: String, ckErrorRawCode: Int?)
}

public enum ICloudCloudKitMVPResultValidator {
    /// Validates a per-record save outcome from `CKDatabase.modifyRecords`.
    /// Throws `ICloudPerRecordValidationError` if the record is missing
    /// or failed; throws the underlying error pass-through so call-sites
    /// keep CKError-code-name extraction.
    public static func assertSaved<RecordID: Hashable, Record>(
        recordID: RecordID,
        in saveResults: [RecordID: Result<Record, Error>]
    ) throws {
        guard let result = saveResults[recordID] else {
            throw ICloudPerRecordValidationError.missingResult
        }
        switch result {
        case .success:
            return
        case .failure(let error):
            // Re-throw the underlying error so the existing
            // `makeFailureResult` path keeps mapping `CKError.Code`.
            throw error
        }
    }

    /// Validates a per-record delete outcome.
    public static func assertDeleted<RecordID: Hashable>(
        recordID: RecordID,
        in deleteResults: [RecordID: Result<Void, Error>]
    ) throws {
        guard let result = deleteResults[recordID] else {
            throw ICloudPerRecordValidationError.missingResult
        }
        switch result {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    /// Validates that *all* expected records appear successfully in the
    /// per-record save outcomes. Used by `CloudKitLiveTrackCloudBackupUploader`
    /// so a partial CloudKit failure cannot silently mark a LiveTrack
    /// backup as „done".
    public static func assertAllSaved<RecordID: Hashable, Record>(
        expectedIDs: [RecordID],
        in saveResults: [RecordID: Result<Record, Error>]
    ) throws {
        for recordID in expectedIDs {
            try assertSaved(recordID: recordID, in: saveResults)
        }
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
        case 11: return .init(codeName: "unknownItem",          germanHint: "Record oder Record-Typ nicht vorhanden (in Lösch-/Idempotenz-Pfaden harmlos).")
        // Korrigiert nach falschem Trust: Code 12 ist NICHT nur „Schema
        // fehlt". Production kann invalidArguments auch werfen für
        // ungültiges Predicate, fehlende Queryable-Indexe auf abgefragten
        // Feldern, ungültige Sort-Descriptors oder unbekannte Field-Namen.
        // Wir zeigen jetzt den Roh-Description, nicht eine geratene
        // Ursache.
        case 12: return .init(codeName: "invalidArguments",     germanHint: "Ungültiges CloudKit-Argument. Prüfe Predicate, Field-Namen und Queryable-Indexe — siehe Roh-Fehler unten.")
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

    /// Prompt 2 — Builder für Restore-Decode aus `CKRecord`.
    public static func empty() -> LiveTrackCloudSummary {
        var s = LiveTrackCloudSummary.fromZero
        s.id = UUID()
        return s
    }

    private static let fromZero = LiveTrackCloudSummary(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        schemaVersion: LiveTrackCloudSchema.schemaVersion,
        localTrackIDHash: "",
        title: "",
        startedAt: Date(timeIntervalSince1970: 0),
        endedAt: Date(timeIntervalSince1970: 0),
        durationSeconds: 0,
        distanceM: 0,
        pointCount: 0,
        hasPointBatches: false,
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0),
        estimatedPayloadBytes: 0
    )

    private init(
        id: UUID,
        schemaVersion: Int,
        localTrackIDHash: String,
        title: String,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: TimeInterval,
        distanceM: Double,
        pointCount: Int,
        hasPointBatches: Bool,
        createdAt: Date,
        updatedAt: Date,
        estimatedPayloadBytes: Int
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.localTrackIDHash = localTrackIDHash
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.distanceM = distanceM
        self.pointCount = pointCount
        self.hasPointBatches = hasPointBatches
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.estimatedPayloadBytes = estimatedPayloadBytes
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

    /// Prompt 2 — Builder für Restore-Decode (alle Properties bereits
    /// im Record vorhanden, kein erneutes Hashen/Encoden nötig).
    public static func empty() -> LiveTrackCloudPointBatch {
        LiveTrackCloudPointBatch(
            schemaVersion: LiveTrackCloudSchema.schemaVersion,
            localTrackIDHash: "",
            batchIndex: 0,
            batchCount: 0,
            pointCount: 0,
            encodedPointsPayload: "",
            estimatedPayloadBytes: 0,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private init(
        schemaVersion: Int,
        localTrackIDHash: String,
        batchIndex: Int,
        batchCount: Int,
        pointCount: Int,
        encodedPointsPayload: String,
        estimatedPayloadBytes: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.localTrackIDHash = localTrackIDHash
        self.batchIndex = batchIndex
        self.batchCount = batchCount
        self.pointCount = pointCount
        self.encodedPointsPayload = encodedPointsPayload
        self.estimatedPayloadBytes = estimatedPayloadBytes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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

    public static func stableSummaryID(fromLocalTrackIDHash hash: String) -> UUID {
        let hex = (hash + String(repeating: "0", count: 32)).prefix(32)
        let uuidString = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
        return UUID(uuidString: String(uuidString)) ?? UUID()
    }

    public static func estimatedSummaryBytes(pointCount: Int) -> Int {
        256 + max(0, pointCount) / 10
    }

    /// Prompt 2 — Reverse-Mapping für Restore. Setzt aus einem Envelope
    /// (Summary + sortierte PointBatches) wieder einen `RecordedTrack`
    /// zusammen.
    ///
    /// Wichtige Verluste/Annahmen:
    /// - Die ursprüngliche `track.id` (UUID) ist **nicht** im CloudKit-
    ///   Schema gespeichert (nur als 16-Hex `localTrackIDHash`). Beim
    ///   Restore wird eine neue UUID erzeugt (über `freshID`-Closure
    ///   injectable für Tests).
    /// - `dayKey` wird aus `summary.startedAt` (`yyyy-MM-dd`, UTC)
    ///   abgeleitet — das ist dieselbe Konvention, die der Recorder
    ///   beim Anlegen verwendet.
    /// - `captureMode` ist im Schema nicht persistiert; Default
    ///   `.foregroundWhileInUse`.
    public static func decodeRecordedTrack(
        from envelope: LiveTrackCloudBackupEnvelope,
        freshID: () -> UUID = { UUID() }
    ) throws -> RecordedTrack {
        let summary = envelope.summary
        let sortedBatches = envelope.pointBatches.sorted { $0.batchIndex < $1.batchIndex }
        if summary.hasPointBatches {
            let expectedCount = sortedBatches.first?.batchCount ?? 0
            let expectedIndices = Array(0..<expectedCount)
            guard !sortedBatches.isEmpty,
                  sortedBatches.allSatisfy({ $0.batchCount == expectedCount }),
                  sortedBatches.map(\.batchIndex) == expectedIndices
            else {
                throw LiveTrackCloudRestoreError.incompletePointBatches(
                    localTrackIDHash: summary.localTrackIDHash
                )
            }
        }
        var points: [RecordedTrackPoint] = []
        for batch in sortedBatches {
            guard let data = Data(base64Encoded: batch.encodedPointsPayload) else {
                throw LiveTrackCloudRestoreError.corruptPointPayload(batchIndex: batch.batchIndex)
            }
            let payload = try JSONDecoder.liveTrackCloud.decode([LiveTrackCloudPointPayload].self, from: data)
            points.append(contentsOf: payload.map { p in
                RecordedTrackPoint(
                    latitude: p.latitude,
                    longitude: p.longitude,
                    timestamp: p.timestamp,
                    horizontalAccuracyM: p.horizontalAccuracyM,
                    altitudeM: p.altitudeM,
                    verticalAccuracyM: p.verticalAccuracyM
                )
            })
        }
        if !sortedBatches.isEmpty, points.count != summary.pointCount {
            throw LiveTrackCloudRestoreError.pointCountMismatch(
                expected: summary.pointCount,
                actual: points.count
            )
        }
        let dayKey = LiveTrackCloudSchema.dayKey(from: summary.startedAt)
        return RecordedTrack(
            id: freshID(),
            startedAt: summary.startedAt,
            endedAt: summary.endedAt,
            dayKey: dayKey,
            distanceM: summary.distanceM,
            captureMode: .foregroundWhileInUse,
            points: points
        )
    }

    public static func dayKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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

public enum LiveTrackCloudRestoreError: Error, Equatable {
    case corruptPointPayload(batchIndex: Int)
    case missingSummaryForBatch(localTrackIDHash: String)
    case incompletePointBatches(localTrackIDHash: String)
    case pointCountMismatch(expected: Int, actual: Int)
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
    /// Prompt 2 — expliziter, vom Nutzer ausgelöster Upload eines
    /// einzelnen bereits gespeicherten LiveTracks. Anders als
    /// `handleCompletedLiveTrack` ignoriert dies das Auto-Backup-Setting,
    /// respektiert aber weiterhin den Health-Gate.
    func uploadManually(_ track: RecordedTrack, includePointBatches: Bool) async throws
    /// Prompt 2 — Restore-Pfad: lädt alle Cloud-Envelopes über den Uploader.
    func fetchRestorableEnvelopes() async throws -> [LiveTrackCloudBackupEnvelope]
}

public extension LiveTrackCloudBackupCoordinator {
    func uploadManually(_ track: RecordedTrack, includePointBatches: Bool) async throws {}
    func fetchRestorableEnvelopes() async throws -> [LiveTrackCloudBackupEnvelope] { [] }
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
            // Korrigiert: gib den echten CKError-Code + Description weiter,
            // statt die Wahrheit hinter einem generischen Satz zu verstecken.
            let ns = error as NSError
            overview.errorMessage = "Cloud-Datenübersicht fehlgeschlagen — CKError #\(ns.code): \(ns.localizedDescription)"
        }
        return overview
    }

    public func deleteCloudData() async throws {
        try await uploader.deleteCloudData()
        overview = .init()
    }

    /// Prompt 2 — manueller Upload. Health-Gate respektiert, Auto-Backup-
    /// Setting wird absichtlich ignoriert (Trigger ist Nutzeraktion).
    public func uploadManually(_ track: RecordedTrack, includePointBatches: Bool) async throws {
        guard healthGate() else {
            throw LiveTrackManualUploadError.healthGateClosed
        }
        let envelope = try LiveTrackCloudSchema.makeEnvelope(
            for: track,
            includePointBatches: includePointBatches
        )
        try await uploader.upload(envelope)
        uploadedTrackIDs.insert(track.id)
        overview.lastSuccessfulBackupAt = Date()
    }

    public func fetchRestorableEnvelopes() async throws -> [LiveTrackCloudBackupEnvelope] {
        try await uploader.fetchAllEnvelopes()
    }
}

public enum LiveTrackManualUploadError: Error, Equatable {
    case healthGateClosed
}

public protocol LiveTrackCloudBackupUploading: Sendable {
    func upload(_ envelope: LiveTrackCloudBackupEnvelope) async throws
    func fetchOverview() async throws -> ICloudStorageOverview
    func deleteCloudData() async throws
    /// Prompt 2 — Restore-Pfad: lädt alle Summary-Records + zugehörige
    /// PointBatch-Records aus dem privaten CloudKit-Bereich und gruppiert
    /// sie zu vollständigen Envelopes. Pagination via `queryCursor`.
    func fetchAllEnvelopes() async throws -> [LiveTrackCloudBackupEnvelope]
}

public extension LiveTrackCloudBackupUploading {
    /// Default-Impl, damit bestehende Mock-Uploader (Tests) ohne Anpassung
    /// weiterhin compilen.
    func fetchAllEnvelopes() async throws -> [LiveTrackCloudBackupEnvelope] { [] }
}

public struct NoopLiveTrackCloudBackupUploader: LiveTrackCloudBackupUploading {
    public init() {}
    public func upload(_ envelope: LiveTrackCloudBackupEnvelope) async throws {}
    public func fetchOverview() async throws -> ICloudStorageOverview { .init() }
    public func deleteCloudData() async throws {}
    public func fetchAllEnvelopes() async throws -> [LiveTrackCloudBackupEnvelope] { [] }
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

        // Phase D.3 — capture per-record save outcomes. Apple's async
        // modifyRecords returns even when the wire request succeeded but
        // the individual record was rejected server-side; we must inspect
        // saveResults[recordID] before claiming the write went through.
        do {
            let (saveResults, _) = try await container.privateCloudDatabase.modifyRecords(
                saving: [record],
                deleting: [],
                savePolicy: .changedKeys,
                atomically: true
            )
            try ICloudCloudKitMVPResultValidator.assertSaved(
                recordID: recordID,
                in: saveResults
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
            // Validate the per-record fetch outcome explicitly: a missing
            // result or a `.failure(CKError.unknownItem)` here both mean
            // the read could not see the record we just wrote.
            try ICloudCloudKitMVPResultValidator.assertSaved(
                recordID: recordID,
                in: fetched
            )
        } catch {
            // Best-effort cleanup: the write succeeded server-side, so
            // try to delete the probe record. Ignore cleanup errors so
            // the original read failure remains the reported cause.
            await bestEffortDelete(recordID: recordID)
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
            let (_, deleteResults) = try await container.privateCloudDatabase.modifyRecords(
                saving: [],
                deleting: [recordID],
                savePolicy: .changedKeys,
                atomically: true
            )
            try ICloudCloudKitMVPResultValidator.assertDeleted(
                recordID: recordID,
                in: deleteResults
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

    /// Phase D.3 best-effort cleanup: the write probe succeeded, the
    /// read/delete failed for an unrelated reason — try to remove the
    /// orphaned probe record so it does not accumulate in the user's
    /// private database. Any error during cleanup is swallowed so the
    /// original failure stays the reported cause.
    private func bestEffortDelete(recordID: CKRecord.ID) async {
        do {
            let (_, deleteResults) = try await container.privateCloudDatabase.modifyRecords(
                saving: [],
                deleting: [recordID],
                savePolicy: .changedKeys,
                atomically: true
            )
            try ICloudCloudKitMVPResultValidator.assertDeleted(
                recordID: recordID,
                in: deleteResults
            )
            #if canImport(OSLog)
            logger.info("CloudKit probe cleanup succeeded")
            #endif
        } catch {
            #if canImport(OSLog)
            logger.error("CloudKit probe cleanup failed: code=\(self.probeCodeName(for: error), privacy: .public)")
            #endif
        }
    }
}

public struct CloudKitLiveTrackCloudBackupUploader: LiveTrackCloudBackupUploading {
    private let containerIdentifier: String
    #if canImport(OSLog)
    private static let logger = Logger(subsystem: "de.roeber.LH2GPXWrapper", category: "iCloud.LiveTrack")
    #endif

    public init(containerIdentifier: String = CloudKitCloudSyncService.defaultContainerIdentifier) {
        self.containerIdentifier = containerIdentifier
    }

    /// Korrigiert: dumpt den vollen NSError (Domain/Code/Description +
    /// userInfo-Keys ServerErrorDescription/NSUnderlyingError) als
    /// `os.Logger.error`-Eintrag, damit der Nutzer in Console.app die
    /// echte CloudKit-Ursache sieht statt nur unsere geratene Hint.
    private static func logCloudKitFailure(_ scope: String, _ error: Error) {
        #if canImport(OSLog)
        let ns = error as NSError
        let server = (ns.userInfo["ServerErrorDescription"] as? String) ?? ""
        let underlying = (ns.userInfo[NSUnderlyingErrorKey] as? NSError).map { "\($0.domain)#\($0.code) \($0.localizedDescription)" } ?? ""
        logger.error("CloudKit \(scope, privacy: .public) failed: domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public) desc=\(ns.localizedDescription, privacy: .public) server=\(server, privacy: .public) underlying=\(underlying, privacy: .public)")
        #endif
    }

    public func upload(_ envelope: LiveTrackCloudBackupEnvelope) async throws {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let records = [Self.makeSummaryRecord(envelope.summary)]
            + envelope.pointBatches.map(Self.makePointBatchRecord)
        // Phase D.3 — explicitly assert every expected per-record save
        // outcome. Without this check, a partial CloudKit failure could
        // silently mark the LiveTrack backup as successful and lose the
        // record server-side (same root cause as the Phase-D.2 health
        // probe regression). Atomic + per-record validation ensures the
        // outbox keeps the envelope on any individual failure.
        let expectedIDs = records.map(\.recordID)
        let (saveResults, _) = try await database.modifyRecords(
            saving: records,
            deleting: [],
            savePolicy: .changedKeys,
            atomically: true
        )
        try ICloudCloudKitMVPResultValidator.assertAllSaved(
            expectedIDs: expectedIDs,
            in: saveResults
        )
    }

    public func fetchOverview() async throws -> ICloudStorageOverview {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let summaryQuery = CKQuery(recordType: LiveTrackCloudSchema.summaryRecordType, predicate: NSPredicate(format: "TRUEPREDICATE"))
        let batchQuery = CKQuery(recordType: LiveTrackCloudSchema.pointBatchRecordType, predicate: NSPredicate(format: "TRUEPREDICATE"))
        let summaries: [(CKRecord.ID, Result<CKRecord, Error>)]
        let batches: [(CKRecord.ID, Result<CKRecord, Error>)]
        do {
            summaries = try await database.records(matching: summaryQuery, resultsLimit: 200).matchResults
        } catch {
            Self.logCloudKitFailure("fetchOverview/summaries", error)
            throw error
        }
        do {
            batches = try await database.records(matching: batchQuery, resultsLimit: 200).matchResults
        } catch {
            Self.logCloudKitFailure("fetchOverview/batches", error)
            throw error
        }
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

    /// Prompt 2 — Restore-Pfad. Lädt alle Summary- und PointBatch-Records
    /// paginiert via `queryCursor` und gruppiert sie nach
    /// `localTrackIDHash` zu vollständigen Envelopes. PointBatches ohne
    /// passende Summary werden ignoriert (vermeidet inkonsistente
    /// Restore-Items aus partiellem Upload).
    public func fetchAllEnvelopes() async throws -> [LiveTrackCloudBackupEnvelope] {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let summaries = try await Self.fetchAllRecords(
            ofType: LiveTrackCloudSchema.summaryRecordType,
            from: database
        )
        let batches = try await Self.fetchAllRecords(
            ofType: LiveTrackCloudSchema.pointBatchRecordType,
            from: database
        )

        let summaryStructs: [LiveTrackCloudSummary] = summaries.compactMap { Self.decodeSummary($0) }
        let batchStructs: [LiveTrackCloudPointBatch] = batches.compactMap { Self.decodePointBatch($0) }
        let batchesByHash = Dictionary(grouping: batchStructs, by: { $0.localTrackIDHash })

        return summaryStructs.map { summary in
            let envelopeBatches = (batchesByHash[summary.localTrackIDHash] ?? [])
                .sorted { $0.batchIndex < $1.batchIndex }
            return LiveTrackCloudBackupEnvelope(
                summary: summary,
                pointBatches: envelopeBatches,
                queuedAt: summary.createdAt
            )
        }
        .sorted { $0.summary.startedAt > $1.summary.startedAt }
    }

    private static func fetchAllRecords(
        ofType recordType: String,
        from database: CKDatabase
    ) async throws -> [CKRecord] {
        var collected: [CKRecord] = []
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "TRUEPREDICATE"))
        do {
            let firstPage = try await database.records(matching: query, resultsLimit: 200)
            collected.append(contentsOf: try records(from: firstPage.matchResults))
            var cursor = firstPage.queryCursor
            while let next = cursor {
                let nextPage = try await database.records(continuingMatchFrom: next, resultsLimit: 200)
                collected.append(contentsOf: try records(from: nextPage.matchResults))
                cursor = nextPage.queryCursor
            }
        } catch {
            // `unknownItem` auf Query-Pfad = RecordType existiert noch
            // nicht in dieser Umgebung (Schema nicht promoted). Restore
            // liefert dann leeren Bucket statt zu werfen.
            if (error as NSError).domain == "CKErrorDomain",
               (error as NSError).code == 11 {
                return []
            }
            throw error
        }
        return collected
    }

    private static func records(
        from matchResults: [(CKRecord.ID, Result<CKRecord, Error>)]
    ) throws -> [CKRecord] {
        try matchResults.map { _, result in
            try result.get()
        }
    }

    private static func decodeSummary(_ record: CKRecord) -> LiveTrackCloudSummary? {
        guard let localHash = record[LiveTrackCloudSchema.SummaryField.localTrackIDHash] as? String,
              let title = record[LiveTrackCloudSchema.SummaryField.title] as? String,
              let startedAt = record[LiveTrackCloudSchema.SummaryField.startedAt] as? Date,
              let endedAt = record[LiveTrackCloudSchema.SummaryField.endedAt] as? Date
        else { return nil }
        let schemaVersion = (record[LiveTrackCloudSchema.SummaryField.schemaVersion] as? Int)
            ?? (record[LiveTrackCloudSchema.SummaryField.schemaVersion] as? NSNumber)?.intValue
            ?? LiveTrackCloudSchema.schemaVersion
        let durationSeconds = (record[LiveTrackCloudSchema.SummaryField.durationSeconds] as? Double)
            ?? endedAt.timeIntervalSince(startedAt)
        let distanceM = (record[LiveTrackCloudSchema.SummaryField.distanceM] as? Double) ?? 0
        let pointCount = (record[LiveTrackCloudSchema.SummaryField.pointCount] as? Int)
            ?? (record[LiveTrackCloudSchema.SummaryField.pointCount] as? NSNumber)?.intValue ?? 0
        let hasPointBatches = (record[LiveTrackCloudSchema.SummaryField.hasPointBatches] as? Bool) ?? false
        let createdAt = (record[LiveTrackCloudSchema.SummaryField.createdAt] as? Date) ?? startedAt
        let updatedAt = (record[LiveTrackCloudSchema.SummaryField.updatedAt] as? Date) ?? createdAt
        let estimated = (record[LiveTrackCloudSchema.SummaryField.estimatedPayloadBytes] as? Int)
            ?? (record[LiveTrackCloudSchema.SummaryField.estimatedPayloadBytes] as? NSNumber)?.intValue ?? 0

        var summary = LiveTrackCloudSummary.empty()
        summary.id = LiveTrackCloudSchema.stableSummaryID(fromLocalTrackIDHash: localHash)
        summary.schemaVersion = schemaVersion
        summary.localTrackIDHash = localHash
        summary.title = title
        summary.startedAt = startedAt
        summary.endedAt = endedAt
        summary.durationSeconds = durationSeconds
        summary.distanceM = distanceM
        summary.pointCount = pointCount
        summary.hasPointBatches = hasPointBatches
        summary.createdAt = createdAt
        summary.updatedAt = updatedAt
        summary.estimatedPayloadBytes = estimated
        return summary
    }

    private static func decodePointBatch(_ record: CKRecord) -> LiveTrackCloudPointBatch? {
        guard let localHash = record[LiveTrackCloudSchema.PointBatchField.localTrackIDHash] as? String,
              let batchIndex = (record[LiveTrackCloudSchema.PointBatchField.batchIndex] as? Int)
                ?? (record[LiveTrackCloudSchema.PointBatchField.batchIndex] as? NSNumber)?.intValue,
              let batchCount = (record[LiveTrackCloudSchema.PointBatchField.batchCount] as? Int)
                ?? (record[LiveTrackCloudSchema.PointBatchField.batchCount] as? NSNumber)?.intValue,
              let encodedPayload = record[LiveTrackCloudSchema.PointBatchField.encodedPointsPayload] as? String
        else { return nil }
        var batch = LiveTrackCloudPointBatch.empty()
        batch.schemaVersion = (record[LiveTrackCloudSchema.PointBatchField.schemaVersion] as? Int)
            ?? (record[LiveTrackCloudSchema.PointBatchField.schemaVersion] as? NSNumber)?.intValue
            ?? LiveTrackCloudSchema.schemaVersion
        batch.localTrackIDHash = localHash
        batch.batchIndex = batchIndex
        batch.batchCount = batchCount
        batch.pointCount = (record[LiveTrackCloudSchema.PointBatchField.pointCount] as? Int)
            ?? (record[LiveTrackCloudSchema.PointBatchField.pointCount] as? NSNumber)?.intValue ?? 0
        batch.encodedPointsPayload = encodedPayload
        batch.estimatedPayloadBytes = (record[LiveTrackCloudSchema.PointBatchField.estimatedPayloadBytes] as? Int)
            ?? (record[LiveTrackCloudSchema.PointBatchField.estimatedPayloadBytes] as? NSNumber)?.intValue ?? 0
        batch.createdAt = (record[LiveTrackCloudSchema.PointBatchField.createdAt] as? Date) ?? Date()
        batch.updatedAt = (record[LiveTrackCloudSchema.PointBatchField.updatedAt] as? Date) ?? batch.createdAt
        return batch
    }

    public func deleteCloudData() async throws {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        // Korrigiert nach Live-Diagnose 2026-05-25: `LH2GPXCloudHealthProbe`
        // ist im Production-Schema NICHT als „indexable" markiert
        // (recordName-QUERYABLE fehlt). Apple meldet das als
        // CKError.invalidArguments / CKInternalErrorDomain #2015
        // „Type is not marked indexable: LH2GPXCloudHealthProbe".
        // Probe-Records sind ohnehin ephemeral und werden vom
        // HealthCheckService selbst per `bestEffortDelete` aufgeräumt —
        // sie hier zu iterieren bringt nichts und brach den ganzen
        // Lösch-Pfad. Liste enthält jetzt nur noch persistente Types.
        let recordTypes = [
            LiveTrackCloudSchema.summaryRecordType,
            LiveTrackCloudSchema.pointBatchRecordType,
        ]
        // Phase D.4 — paginate via `queryCursor` so we drain every page
        // of records, not just the first 200. Without this, a user with
        // many LiveTrack-PointBatches saw the destructive button silently
        // leave most records behind in CloudKit.
        for recordType in recordTypes {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "TRUEPREDICATE"))
            var pendingDeleteIDs: [CKRecord.ID] = []
            var cursor: CKQueryOperation.Cursor?
            do {
                let firstPage = try await database.records(matching: query, resultsLimit: 200)
                pendingDeleteIDs.append(contentsOf: firstPage.matchResults.compactMap { _, result in
                    if case .success(let record) = result { return record.recordID }
                    return nil
                })
                cursor = firstPage.queryCursor
                while let next = cursor {
                    let nextPage = try await database.records(continuingMatchFrom: next, resultsLimit: 200)
                    pendingDeleteIDs.append(contentsOf: nextPage.matchResults.compactMap { _, result in
                        if case .success(let record) = result { return record.recordID }
                        return nil
                    })
                    cursor = nextPage.queryCursor
                }
            } catch {
                Self.logCloudKitFailure("deleteCloudData/query[\(recordType)]", error)
                let nsError = error as NSError
                // Phase D.4 — `unknownItem` auf Query-Pfad = RecordType
                // existiert nicht in dieser Env. Skip.
                if nsError.domain == "CKErrorDomain", nsError.code == 11 {
                    continue
                }
                // Korrigiert nach Live-Diagnose 2026-05-25: Apple meldet
                // fehlenden recordName-Queryable-Index als invalidArguments
                // (Code 12) mit Server-Text „Type is not marked indexable".
                // Wir behandeln das wie unknownItem — der Type ist in dieser
                // Env nicht abfragbar, also gibt es aus App-Sicht „nichts zu
                // löschen". User-Hinweis: Index im Dashboard nachziehen.
                if nsError.domain == "CKErrorDomain", nsError.code == 12 {
                    let server = (nsError.userInfo["ServerErrorDescription"] as? String) ?? ""
                    let underlying = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.localizedDescription ?? ""
                    if server.contains("not marked indexable") || underlying.contains("not marked indexable") {
                        continue
                    }
                }
                throw error
            }
            do {
                try await deleteInChunks(pendingDeleteIDs, database: database)
            } catch {
                Self.logCloudKitFailure("deleteCloudData/delete[\(recordType)]", error)
                throw error
            }
        }
    }

    /// Phase D.4 — deletes records in batches of 200 and validates each
    /// per-record outcome via the shared `ICloudCloudKitMVPResultValidator`.
    /// `CKError.unknownItem` for a record-ID that is „already gone" is
    /// treated as idempotent success (HIG/Apple convention — record is
    /// in the desired terminal state).
    private func deleteInChunks(_ ids: [CKRecord.ID], database: CKDatabase) async throws {
        guard !ids.isEmpty else { return }
        let chunkSize = 200
        for chunkStart in stride(from: 0, to: ids.count, by: chunkSize) {
            let chunk = Array(ids[chunkStart..<min(chunkStart + chunkSize, ids.count)])
            let (_, deleteResults) = try await database.modifyRecords(
                saving: [],
                deleting: chunk,
                savePolicy: .changedKeys,
                atomically: false
            )
            for recordID in chunk {
                do {
                    try ICloudCloudKitMVPResultValidator.assertDeleted(
                        recordID: recordID,
                        in: deleteResults
                    )
                } catch {
                    // Idempotent: record was already gone server-side.
                    if (error as NSError).domain == "CKErrorDomain",
                       (error as NSError).code == 11 /* unknownItem */ {
                        continue
                    }
                    throw error
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
