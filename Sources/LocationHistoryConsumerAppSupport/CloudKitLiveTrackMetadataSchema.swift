#if canImport(CloudKit)
import Foundation
import CloudKit

// MARK: - LiveTrackMetadata (value type)

/// Foundation-only value type that mirrors the field shape of the future
/// `LiveTrackMeta` CKRecord. Train F.2 introduces *only* the schema —
/// no records are read, written, queried, deleted, subscribed-to, or
/// uploaded as assets. The mapping helpers below convert between this
/// value type and a `CKRecord` so future trains (and Apple's CloudKit
/// Dashboard schema-from-code workflow) can adopt the schema without
/// further refactoring.
///
/// **What this type is NOT**: it is *not* a snapshot of a live recording.
/// It carries deliberately reduced metadata only:
/// `schemaVersion`, `startedAt`, `endedAt`, `pointCount`, `distanceM`,
/// `sourceFilename`, `createdAt`, `updatedAt`. **No coordinates, no
/// polylines, no raw points, no place IDs, no visit data.** A user
/// looking at the iCloud record could see *that* a track existed and
/// how big it was — never *where* the user was.
public struct LiveTrackMetadata: Sendable, Equatable {
    public var schemaVersion: Int
    public var startedAt: Date
    public var endedAt: Date?
    public var pointCount: Int
    public var distanceM: Double?
    public var sourceFilename: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = LiveTrackMetadataSchema.currentSchemaVersion,
        startedAt: Date,
        endedAt: Date? = nil,
        pointCount: Int,
        distanceM: Double? = nil,
        sourceFilename: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.pointCount = pointCount
        self.distanceM = distanceM
        self.sourceFilename = sourceFilename
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Schema constants + mapping

/// Schema descriptor + CKRecord mapping for `LiveTrackMeta`. The mapping
/// is intentionally inert: no `CKDatabase` reference is captured here,
/// no `save`/`fetch`/`perform`/`delete`/`modifyRecords` calls are made
/// from this file. The type only knows how to *shape* a `CKRecord` and
/// how to *parse* one back into a `LiveTrackMetadata` value.
public enum LiveTrackMetadataSchema {
    /// CloudKit record type name. Alphanumeric + underscore, does not
    /// start with `_` (reserved by CloudKit for system record types).
    public static let recordType: CKRecord.RecordType = "LiveTrackMeta"

    /// First schema version. Future schema changes bump this integer
    /// and add new optional fields — old records without the new field
    /// are accepted with a `nil`/default fallback.
    public static let currentSchemaVersion: Int = 1

    /// CKRecord field names. Names use camelCase to match Apple's
    /// CloudKit Dashboard "Add field" convention.
    public enum Field {
        public static let schemaVersion = "schemaVersion"
        public static let startedAt = "startedAt"
        public static let endedAt = "endedAt"
        public static let pointCount = "pointCount"
        public static let distanceM = "distanceM"
        public static let sourceFilename = "sourceFilename"
        public static let createdAt = "createdAt"
        public static let updatedAt = "updatedAt"
    }

    /// Builds a fresh `CKRecord` for the given metadata. The caller
    /// supplies the `CKRecord.ID` so the record can live in a custom
    /// zone if the future write path chooses one; default is the
    /// default zone in whichever database the caller picks (Phase B
    /// will pick `privateCloudDatabase` exclusively).
    ///
    /// This function does **not** call any `CKDatabase` API. It is pure
    /// data shaping.
    public static func makeRecord(
        from metadata: LiveTrackMetadata,
        recordID: CKRecord.ID = CKRecord.ID(recordName: UUID().uuidString)
    ) -> CKRecord {
        let record = CKRecord(recordType: recordType, recordID: recordID)
        apply(metadata, to: record)
        return record
    }

    /// Writes `metadata` into an existing `CKRecord`. Useful for the
    /// future update path that round-trips a fetched record.
    public static func apply(_ metadata: LiveTrackMetadata, to record: CKRecord) {
        record[Field.schemaVersion] = metadata.schemaVersion as CKRecordValue
        record[Field.startedAt] = metadata.startedAt as CKRecordValue
        if let endedAt = metadata.endedAt {
            record[Field.endedAt] = endedAt as CKRecordValue
        } else {
            record[Field.endedAt] = nil
        }
        record[Field.pointCount] = metadata.pointCount as CKRecordValue
        if let distanceM = metadata.distanceM {
            record[Field.distanceM] = distanceM as CKRecordValue
        } else {
            record[Field.distanceM] = nil
        }
        if let sourceFilename = metadata.sourceFilename {
            record[Field.sourceFilename] = sourceFilename as CKRecordValue
        } else {
            record[Field.sourceFilename] = nil
        }
        record[Field.createdAt] = metadata.createdAt as CKRecordValue
        record[Field.updatedAt] = metadata.updatedAt as CKRecordValue
    }

    /// Parses a `CKRecord` into a `LiveTrackMetadata`. Returns `nil`
    /// when the record type does not match or required fields are
    /// missing. Unknown additional fields are tolerated and ignored —
    /// keeps forward compatibility when the schema is extended.
    public static func metadata(from record: CKRecord) -> LiveTrackMetadata? {
        guard record.recordType == recordType else { return nil }
        guard let startedAt = record[Field.startedAt] as? Date,
              let pointCount = (record[Field.pointCount] as? Int)
                ?? (record[Field.pointCount] as? NSNumber)?.intValue,
              let createdAt = record[Field.createdAt] as? Date,
              let updatedAt = record[Field.updatedAt] as? Date
        else {
            return nil
        }
        let schemaVersion = (record[Field.schemaVersion] as? Int)
            ?? (record[Field.schemaVersion] as? NSNumber)?.intValue
            ?? currentSchemaVersion
        let endedAt = record[Field.endedAt] as? Date
        let distanceM = (record[Field.distanceM] as? Double)
            ?? (record[Field.distanceM] as? NSNumber)?.doubleValue
        let sourceFilename = record[Field.sourceFilename] as? String
        return LiveTrackMetadata(
            schemaVersion: schemaVersion,
            startedAt: startedAt,
            endedAt: endedAt,
            pointCount: pointCount,
            distanceM: distanceM,
            sourceFilename: sourceFilename,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

#endif
